# -*- coding: utf-8 -*-
"""
LaserTuner ML API v3.0 - DIODE LASER EDITION
Backend API for Diode Laser Machines (2W-40W)
🎯 FIREBASE-FIRST STRATEGY: Model only in Firebase Storage
"""
import sys
import io
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

from online_learning_service import get_online_learner 
from ml_feature_engineering import get_feature_encoder
from ml_transfer_model import get_transfer_model, TF_AVAILABLE
from fastapi import FastAPI, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from pydantic import BaseModel, Field, validator
from typing import List, Dict, Optional
import logging
import os
import numpy as np
from datetime import datetime
from dotenv import load_dotenv

# Import our services
from firebase_service import get_firebase_service
from model_storage_service import get_storage_service

# Load environment variables
load_dotenv()

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[logging.StreamHandler()]
)
logger = logging.getLogger(__name__)

# ✅ GLOBAL VARIABLES for Transfer Learning
transfer_model = None
feature_encoder = None

# Initialize FastAPI app
app = FastAPI(
    title="LaserTuner ML API - Diode Laser Edition",
    version="3.0.0-firebase-first",
    description="AI-powered diode laser cutting parameter prediction (2W-40W) - Firebase Storage Model"
)

# CORS Configuration
ALLOWED_ORIGINS = os.getenv(
    "ALLOWED_ORIGINS",
    "https://lasertuner.netlify.app,http://localhost:8080,http://localhost:*"
).split(",")

app.add_middleware(
    CORSMiddleware,
    allow_origins=ALLOWED_ORIGINS,
    allow_credentials=True,
    allow_methods=["GET", "POST", "OPTIONS"],
    allow_headers=["Content-Type", "Authorization"],
)

# ============= MODELS =============

class ProcessParams(BaseModel):
    """Process parameters for diode laser operations"""
    power: float = Field(..., ge=5, le=100, description="Power percentage (5-100%)")
    speed: float = Field(..., ge=50, le=500, description="Speed in mm/min")
    passes: int = Field(..., ge=1, le=20, description="Number of passes")


class PredictionRequest(BaseModel):
    """Request model for parameter prediction"""
    machineBrand: str = Field(..., min_length=1, max_length=100)
    laserPower: float = Field(..., gt=0, description="Laser power in Watts (must be > 0)")
    materialType: str = Field(..., min_length=1, max_length=50)
    materialThickness: float = Field(..., gt=0, description="Thickness in mm (must be > 0)")
    processes: List[str] = Field(..., min_items=1, max_items=3)

    @validator('processes')
    def validate_processes(cls, v):
        valid_processes = {'cutting', 'engraving', 'scoring'}
        invalid = [p for p in v if p not in valid_processes]
        if invalid:
            raise ValueError(f"Geçersiz işlem türleri: {invalid}")
        if len(v) != len(set(v)):
            raise ValueError("Tekrar eden işlem türlerine izin verilmiyor")
        return v
    
    @validator('materialType')
    def validate_material(cls, v):
        """✅ AppConfig uyumlu malzeme validasyonu"""
        valid_materials = {
            'ahşap', 'ahsap', 'wood', 'kontrplak', 'plywood', 'mdf', 'balsa',
            'bambu', 'bamboo', 'kayın', 'kayin', 'beech', 'meşe', 'mese', 'oak',
            'ceviz', 'walnut', 'akçaağaç', 'akcaagac', 'maple', 'huş', 'hus', 
            'birch', 'çam', 'cam', 'pine', 'ladin', 'spruce', 'fir',
            'deri', 'leather', 'karton', 'cardboard', 'kağıt', 'kagit', 'paper', 
            'kumaş', 'kumas', 'fabric', 'keçe', 'kece', 'felt', 'mantar', 'cork', 
            'akrilik', 'acrylic', 'plexiglass', 'pleksiglas', 'pmma',
            'lastik', 'rubber', 'köpük', 'kopuk', 'foam', 'anodize_aluminyum',
            'anodized_aluminum', 'diger', 'other'
        }
        
        v_lower = v.lower().strip()
        if v_lower in valid_materials:
            return v
        
        for valid in valid_materials:
            if valid in v_lower or v_lower in valid:
                logger.info(f"✅ Material matched: '{v}' → '{valid}'")
                return v
        
        logger.warning(f"⚠️ Unknown material: {v}, allowing for flexibility")
        return v


class PredictionResponse(BaseModel):
    """Response model for predictions"""
    predictions: Dict[str, ProcessParams]
    confidenceScore: float = Field(..., ge=0, le=1)
    notes: str
    dataPointsUsed: int = Field(default=0, ge=0)
    dataSource: str = Field(default="static_algorithm")
    warnings: List[str] = Field(default_factory=list)


class HealthResponse(BaseModel):
    """Health check response"""
    status: str
    service: str
    version: str
    laserType: str
    powerRange: str
    timestamp: str
    firebase_status: str = "unknown"
    total_experiments: int = 0


# ============= DIODE LASER PARAMETERS =============

def get_diode_material_params(material: str) -> Dict:
    """Get base parameters for diode laser materials"""
    material = material.lower().strip()
    
    params = {
        # WOOD MATERIALS
        'ahşap': {'base_power': 80, 'power_mult': 4.0, 'base_speed': 300, 'speed_mult': 30, 'base_passes': 2, 'passes_mult': 0.5},
        'ahsap': {'base_power': 80, 'power_mult': 4.0, 'base_speed': 300, 'speed_mult': 30, 'base_passes': 2, 'passes_mult': 0.5},
        'wood': {'base_power': 80, 'power_mult': 4.0, 'base_speed': 300, 'speed_mult': 30, 'base_passes': 2, 'passes_mult': 0.5},
        'kontrplak': {'base_power': 82, 'power_mult': 4.2, 'base_speed': 290, 'speed_mult': 32, 'base_passes': 2, 'passes_mult': 0.5},
        'plywood': {'base_power': 82, 'power_mult': 4.2, 'base_speed': 290, 'speed_mult': 32, 'base_passes': 2, 'passes_mult': 0.5},
        'mdf': {'base_power': 85, 'power_mult': 4.5, 'base_speed': 280, 'speed_mult': 35, 'base_passes': 2, 'passes_mult': 0.6},
        'balsa': {'base_power': 60, 'power_mult': 2.5, 'base_speed': 380, 'speed_mult': 20, 'base_passes': 1, 'passes_mult': 0.3},
        'bambu': {'base_power': 85, 'power_mult': 4.5, 'base_speed': 280, 'speed_mult': 35, 'base_passes': 2, 'passes_mult': 0.6},
        'bamboo': {'base_power': 85, 'power_mult': 4.5, 'base_speed': 280, 'speed_mult': 35, 'base_passes': 2, 'passes_mult': 0.6},
        'ladin': {'base_power': 75, 'power_mult': 3.5, 'base_speed': 320, 'speed_mult': 28, 'base_passes': 2, 'passes_mult': 0.4},
        'spruce': {'base_power': 75, 'power_mult': 3.5, 'base_speed': 320, 'speed_mult': 28, 'base_passes': 2, 'passes_mult': 0.4},
        'fir': {'base_power': 75, 'power_mult': 3.5, 'base_speed': 320, 'speed_mult': 28, 'base_passes': 2, 'passes_mult': 0.4},
        
        # ORGANIC MATERIALS
        'deri': {'base_power': 70, 'power_mult': 3.5, 'base_speed': 350, 'speed_mult': 28, 'base_passes': 1, 'passes_mult': 0.4},
        'leather': {'base_power': 70, 'power_mult': 3.5, 'base_speed': 350, 'speed_mult': 28, 'base_passes': 1, 'passes_mult': 0.4},
        
        # SYNTHETIC MATERIALS
        'akrilik': {'base_power': 75, 'power_mult': 4.0, 'base_speed': 280, 'speed_mult': 30, 'base_passes': 2, 'passes_mult': 0.5},
        'acrylic': {'base_power': 75, 'power_mult': 4.0, 'base_speed': 280, 'speed_mult': 30, 'base_passes': 2, 'passes_mult': 0.5},
        'plexiglass': {'base_power': 75, 'power_mult': 4.0, 'base_speed': 280, 'speed_mult': 30, 'base_passes': 2, 'passes_mult': 0.5},
        'pleksiglas': {'base_power': 75, 'power_mult': 4.0, 'base_speed': 280, 'speed_mult': 30, 'base_passes': 2, 'passes_mult': 0.5},
        'pmma': {'base_power': 75, 'power_mult': 4.0, 'base_speed': 280, 'speed_mult': 30, 'base_passes': 2, 'passes_mult': 0.5},
    }
    
    if material in params:
        return params[material]
    
    for key in params.keys():
        if key in material or material in key:
            logger.info(f"✅ Material param matched: '{material}' → '{key}'")
            return params[key]
    
    logger.warning(f"⚠️ Using default params for material: {material}")
    return {'base_power': 75, 'power_mult': 3.5, 'base_speed': 320, 
            'speed_mult': 25, 'base_passes': 2, 'passes_mult': 0.4}


def calculate_diode_cutting_params(material: str, thickness: float) -> ProcessParams:
    """Calculate cutting parameters for diode laser"""
    params = get_diode_material_params(material)
    power = params['base_power'] + (thickness * params['power_mult'])
    power = round(max(10, min(100, power)), 1)
    speed = params['base_speed'] - (thickness * params['speed_mult'])
    speed = round(max(50, min(500, speed)), 0)
    passes = params['base_passes'] + int(thickness * params['passes_mult'])
    passes = max(1, min(20, passes))
    return ProcessParams(power=power, speed=speed, passes=passes)


def calculate_diode_engraving_params(material: str, thickness: float) -> ProcessParams:
    """Calculate engraving parameters"""
    params = get_diode_material_params(material)
    power = (params['base_power'] * 0.5) + (thickness * 1.5)
    power = round(max(10, min(100, power)), 1)
    speed = params['base_speed'] + 100
    speed = round(max(100, min(500, speed)), 0)
    passes = 1
    return ProcessParams(power=power, speed=speed, passes=passes)


def calculate_diode_scoring_params(material: str, thickness: float) -> ProcessParams:
    """Calculate scoring parameters"""
    params = get_diode_material_params(material)
    power = (params['base_power'] * 0.7) + (thickness * 2.5)
    power = round(max(10, min(100, power)), 1)
    speed = params['base_speed'] + 50
    speed = round(max(80, min(500, speed)), 0)
    passes = max(1, int(thickness * 0.3))
    passes = max(1, min(10, passes))
    return ProcessParams(power=power, speed=speed, passes=passes)


# ============= API ENDPOINTS =============

@app.get("/", response_model=HealthResponse)
async def root():
    """Root endpoint"""
    firebase = get_firebase_service()
    stats = firebase.get_statistics() if firebase.is_available() else {}
    return HealthResponse(
        status="healthy",
        service="LaserTuner ML API - Firebase-First Edition",
        version="3.0.0-firebase-first",
        laserType="Diode Laser",
        powerRange="2W - 40W",
        timestamp=datetime.utcnow().isoformat(),
        firebase_status="connected" if firebase.is_available() else "disconnected",
        total_experiments=stats.get('total_experiments', 0)
    )


@app.get("/health", response_model=HealthResponse)
async def health_check():
    """Health check"""
    firebase = get_firebase_service()
    stats = firebase.get_statistics() if firebase.is_available() else {}
    return HealthResponse(
        status="healthy",
        service="LaserTuner ML API - Firebase-First Edition",
        version="3.0.0-firebase-first",
        laserType="Diode Laser",
        powerRange="2W - 40W",
        timestamp=datetime.utcnow().isoformat(),
        firebase_status="connected" if firebase.is_available() else "disconnected",
        total_experiments=stats.get('total_experiments', 0)
    )


@app.post("/predict", response_model=PredictionResponse)
async def predict(request: PredictionRequest):
    """
    🤖 TRANSFER LEARNING PREDICTION ENDPOINT
    
    Flow:
    1. Try transfer learning model (if trained)
    2. Fallback to static algorithm if needed
    """
    start_time = datetime.now()
    
    try:
        logger.info(
            f"🔥 Prediction request: {request.machineBrand} {request.laserPower}W, "
            f"{request.materialType} {request.materialThickness}mm, processes: {request.processes}"
        )
        
        warnings = []
        if request.materialThickness > 8:
            warnings.append(f"⚠️ {request.materialThickness}mm kalınlık zorlu olabilir")
        if request.materialThickness > 5 and request.laserPower < 20:
            warnings.append(f"⚠️ {request.laserPower}W güç düşük olabilir")
        
        predictions = {}
        data_source = "static_algorithm"
        confidence_score = 0.60
        notes = ""
        
        # ===== TRY TRANSFER LEARNING FIRST =====
        if transfer_model and TF_AVAILABLE and feature_encoder and transfer_model.is_trained:
            try:
                logger.info("🤖 Using trained transfer learning model...")
                
                for process_type in request.processes:
                    # Encode features (9 numerical features)
                    features = feature_encoder.encode(
                        material_type=request.materialType,
                        thickness=request.materialThickness,
                        laser_power=request.laserPower,
                        process_type=process_type
                    )
                    
                    # Predict (normalized 0-1 outputs)
                    X = features.reshape(1, -1)
                    power_norm, speed_norm, passes_norm = transfer_model.predict(X)
                    
                    # Denormalize predictions
                    pred = feature_encoder.decode_predictions(
                        power_norm[0][0],
                        speed_norm[0][0],
                        passes_norm[0][0]
                    )
                    
                    predictions[process_type] = ProcessParams(
                        power=float(pred['power']),
                        speed=float(pred['speed']),
                        passes=int(pred['passes'])
                    )
                    
                    logger.info(
                        f"✅ {process_type}: TL → power={pred['power']:.1f}%, "
                        f"speed={pred['speed']:.0f}mm/min, passes={pred['passes']}"
                    )
                
                data_source = "transfer_learning"
                confidence_score = 0.85
                notes = "🤖 Transfer learning model (Firebase Storage'dan yüklendi)"
                
            except Exception as e:
                logger.warning(f"⚠️ Transfer learning prediction failed: {e}")
                predictions = {}
        elif transfer_model and not transfer_model.is_trained:
            logger.info("ℹ️ Model exists but UNTRAINED, using static algorithm")
            predictions = {}
        
        # ===== FALLBACK: STATIC ALGORITHM =====
        if not predictions:
            if transfer_model and not transfer_model.is_trained:
                logger.info("⚙️ Using static algorithm (model exists but untrained)")
            else:
                logger.info("⚙️ Using static algorithm fallback")
            
            for process_type in request.processes:
                if process_type == 'cutting':
                    params = calculate_diode_cutting_params(
                        request.materialType, request.materialThickness
                    )
                elif process_type == 'engraving':
                    params = calculate_diode_engraving_params(
                        request.materialType, request.materialThickness
                    )
                elif process_type == 'scoring':
                    params = calculate_diode_scoring_params(
                        request.materialType, request.materialThickness
                    )
                else:
                    params = ProcessParams(power=50.0, speed=300.0, passes=2)
                
                predictions[process_type] = params
            
            data_source = "static_algorithm"
            confidence_score = 0.60
            
            if transfer_model and not transfer_model.is_trained:
                notes = "⚙️ Statik algoritma (Model Firebase'de yok veya eğitilmemiş - 50+ doğrulanmış deney gerekli)"
            else:
                notes = "⚙️ Statik algoritma (TL model yok veya başarısız)"
        
        response = PredictionResponse(
            predictions=predictions,
            confidenceScore=confidence_score,
            notes=notes,
            dataPointsUsed=0,
            dataSource=data_source,
            warnings=warnings
        )
        
        duration = (datetime.now() - start_time).total_seconds()
        logger.info(f"✅ Prediction complete in {duration:.3f}s, source: {data_source}")
        
        return response
        
    except ValueError as e:
        logger.warning(f"❌ Validation error: {str(e)}")
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        logger.exception(f"❌ Unexpected error: {str(e)}")
        raise HTTPException(status_code=500, detail="Tahmin hatası")


@app.get("/test")
async def test_endpoint():
    """Test endpoint with Firebase Storage info"""
    firebase = get_firebase_service()
    storage_service = get_storage_service()
    stats = firebase.get_statistics() if firebase.is_available() else {}
    
    model_info = {}
    if storage_service.is_available():
        model_metadata = storage_service.get_model_metadata()
        if model_metadata:
            model_info = {
                'exists_in_storage': True,
                'size_mb': round(model_metadata['size_mb'], 2),
                'last_updated': str(model_metadata['updated']),
            }
        else:
            model_info = {'exists_in_storage': False}
    
    return {
        "status": "ok",
        "version": "3.0.0-firebase-first",
        "strategy": "Firebase Storage as single source of truth",
        "transfer_learning_enabled": TF_AVAILABLE and transfer_model is not None,
        "transfer_learning_trained": transfer_model.is_trained if transfer_model else False,
        "firebase_firestore_connected": firebase.is_available(),
        "firebase_storage_connected": storage_service.is_available(),
        "model_storage": model_info,
        "total_experiments": stats.get('total_experiments', 0),
        "verified_experiments": stats.get('verified_experiments', 0),
    }


@app.get("/admin/storage-debug")
async def storage_debug():
    """Firebase Storage debug bilgisi"""
    storage_service = get_storage_service()
    
    return {
        "storage_available": storage_service.is_available(),
        "bucket_name": storage_service.bucket_name,
        "model_path": storage_service.model_path,
        "model_exists_in_storage": storage_service.model_exists_in_storage() if storage_service.is_available() else False,
        "storage_info": storage_service.get_storage_info(),
    }


@app.post("/admin/fine-tune")
async def fine_tune_model():
    """
    Admin endpoint: Fine-tune model with latest Firebase data
    
    Flow:
    1. Use current model in memory (from Firebase)
    2. Fine-tune with new data
    3. Upload updated model back to Firebase
    
    Usage: POST /admin/fine-tune
    """
    global transfer_model
    
    if not TF_AVAILABLE:
        raise HTTPException(status_code=503, detail="TensorFlow not available")
    
    firebase = get_firebase_service()
    storage_service = get_storage_service()
    
    if not firebase.is_available():
        raise HTTPException(status_code=503, detail="Firebase Firestore not available")
    
    if not storage_service.is_available():
        raise HTTPException(status_code=503, detail="Firebase Storage not available")
    
    try:
        # 1. Ensure we have latest model
        if not transfer_model or not transfer_model.is_trained:
            raise HTTPException(status_code=400, detail="No trained model available. Train first.")
        
        # 2. Get training data
        logger.info("📊 Fetching training data...")
        training_data = firebase.get_training_data_for_transfer_learning(limit=500)
        
        if len(training_data) < 30:
            raise HTTPException(
                status_code=400, 
                detail=f"Insufficient data for fine-tuning: {len(training_data)} samples (need 30+)"
            )
        
        # 3. Encode data
        feature_encoder = get_feature_encoder()
        X, y_power, y_speed, y_passes = feature_encoder.encode_batch(training_data)
        logger.info(f"✅ Encoded {len(X)} training samples")
        
        # 4. Fine-tune
        logger.info("🔄 Fine-tuning model...")
        history = transfer_model.fine_tune(X, y_power, y_speed, y_passes, epochs=50)
        
        # 5. Save locally (temporary)
        local_model_path = "models/diode_laser_transfer_v1.h5"
        os.makedirs("models", exist_ok=True)
        transfer_model.save_model(local_model_path)
        
        # 6. Upload to Firebase (CRITICAL)
        logger.info("📤 Uploading fine-tuned model to Firebase Storage...")
        success = storage_service.save_model_to_storage(local_model_path)
        
        if not success:
            raise HTTPException(status_code=500, detail="Failed to upload to Firebase Storage")
        
        # 7. Get metadata
        metadata = storage_service.get_model_metadata()
        
        logger.info("✅ Fine-tuning complete and uploaded to Firebase")
        
        return {
            "status": "success",
            "message": "Model fine-tuned and uploaded to Firebase Storage",
            "training_samples": len(X),
            "final_loss": history.get('val_loss', [])[-1] if history else None,
            "model_size_mb": round(metadata['size_mb'], 2) if metadata else None,
            "updated_at": str(metadata['updated']) if metadata else None,
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.exception("Fine-tuning error")
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/admin/train-from-scratch")
async def train_from_scratch():
    """
    Admin endpoint: Train completely new model and upload to Firebase
    
    WARNING: This replaces the existing model in Firebase Storage
    
    Usage: POST /admin/train-from-scratch
    """
    global transfer_model
    
    if not TF_AVAILABLE:
        raise HTTPException(status_code=503, detail="TensorFlow not available")
    
    firebase = get_firebase_service()
    storage_service = get_storage_service()
    
    if not firebase.is_available():
        raise HTTPException(status_code=503, detail="Firebase Firestore not available")
    
    if not storage_service.is_available():
        raise HTTPException(status_code=503, detail="Firebase Storage not available")
    
    try:
        # 1. Get training data
        logger.info("📊 Fetching training data...")
        training_data = firebase.get_training_data_for_transfer_learning(limit=500)
        
        if len(training_data) < 30:
            raise HTTPException(
                status_code=400, 
                detail=f"Insufficient data for training: {len(training_data)} samples (need 30+)"
            )
        
        # 2. Encode data
        feature_encoder = get_feature_encoder()
        X, y_power, y_speed, y_passes = feature_encoder.encode_batch(training_data)
        logger.info(f"✅ Encoded {len(X)} training samples")
        
        # 3. Create new model
        logger.info("🆕 Creating fresh model architecture...")
        transfer_model = get_transfer_model()
        
        # 4. Train from scratch
        local_model_path = "models/diode_laser_transfer_v1.h5"
        os.makedirs("models", exist_ok=True)
        
        logger.info("🔄 Training model from scratch...")
        history = transfer_model.train(
            X, y_power, y_speed, y_passes, 
            epochs=100, 
            save_path=local_model_path
        )
        
        # 5. Upload to Firebase (CRITICAL)
        logger.info("📤 Uploading trained model to Firebase Storage...")
        success = storage_service.save_model_to_storage(local_model_path)
        
        if not success:
            raise HTTPException(status_code=500, detail="Failed to upload to Firebase Storage")
        
        # 6. Get metadata
        metadata = storage_service.get_model_metadata()
        
        logger.info("✅ Training complete and uploaded to Firebase")
        
        return {
            "status": "success",
            "message": "New model trained and uploaded to Firebase Storage",
            "training_samples": len(X),
            "final_loss": history.get('val_loss', [])[-1] if history else None,
            "model_size_mb": round(metadata['size_mb'], 2) if metadata else None,
            "updated_at": str(metadata['updated']) if metadata else None,
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.exception("Training error")
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/admin/reload-model-from-firebase")
async def reload_model_from_firebase():
    """
    Admin endpoint: Force reload model from Firebase Storage
    
    Useful when another server instance uploaded a new model
    
    Usage: POST /admin/reload-model-from-firebase
    """
    global transfer_model
    
    storage_service = get_storage_service()
    
    if not storage_service.is_available():
        raise HTTPException(status_code=503, detail="Firebase Storage not available")
    
    if not TF_AVAILABLE:
        raise HTTPException(status_code=503, detail="TensorFlow not available")
    
    try:
        local_model_path = "models/diode_laser_transfer_v1.h5"
        
        # Download from Firebase Storage
        logger.info("📥 Downloading model from Firebase Storage...")
        success = storage_service.load_model_from_storage(local_model_path)
        
        if not success:
            raise HTTPException(status_code=404, detail="Model not found in Firebase Storage")
        
        # Load the model
        logger.info("🔄 Loading model into memory...")
        transfer_model = get_transfer_model(local_model_path)
        
        # Get metadata
        metadata = storage_service.get_model_metadata()
        
        logger.info("✅ Model reloaded from Firebase Storage")
        
        return {
            "status": "success",
            "message": "Model reloaded from Firebase Storage",
            "is_trained": transfer_model.is_trained,
            "model_size_mb": round(metadata['size_mb'], 2) if metadata else None,
            "updated_at": str(metadata['updated']) if metadata else None,
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.exception("Model reload error")
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/admin/reset-model")
async def reset_model():
    """
    DANGER: Delete model from Firebase Storage
    Next restart will create fresh model
    
    Usage: POST /admin/reset-model
    """
    storage_service = get_storage_service()
    
    if not storage_service.is_available():
        raise HTTPException(status_code=503, detail="Firebase Storage not available")
    
    try:
        success = storage_service.delete_model_from_storage()
        
        if success:
            return {
                "status": "success",
                "message": "Model deleted from Firebase Storage",
                "note": "Next server restart will create fresh model if data available"
            }
        else:
            raise HTTPException(status_code=500, detail="Failed to delete model")
            
    except Exception as e:
        logger.exception("Model deletion error")
        raise HTTPException(status_code=500, detail=str(e))


# ============= STARTUP =============

@app.on_event("startup")
async def startup_event():
    """
    🚀 FIREBASE-FIRST MODEL STRATEGY
    
    Steps:
    1. Initialize feature encoder
    2. Connect to Firebase (Firestore + Storage)
    3. Try to load model from Firebase Storage (ONLY SOURCE)
    4. If not in Firebase, create new + train + upload
    5. Never use local files as source of truth
    """
    global transfer_model, feature_encoder
    
    logger.info("="*80)
    logger.info("🚀 LaserTuner ML API v3.0 - FIREBASE-FIRST STRATEGY")
    logger.info("🎯 Model Source: Firebase Storage ONLY (no local fallback)")
    logger.info("="*80)
    logger.info(f"🤖 TensorFlow Available: {TF_AVAILABLE}")
    
    # 1. Initialize feature encoder
    try:
        feature_encoder = get_feature_encoder()
        logger.info("✅ Feature encoder initialized")
    except Exception as e:
        logger.error(f"❌ Feature encoder failed: {e}")
        feature_encoder = None
    
    # 2. Initialize Firebase
    firebase = get_firebase_service()
    storage_service = get_storage_service()
    
    if not firebase.is_available():
        logger.error("❌ Firebase Firestore not available - CRITICAL")
    else:
        stats = firebase.get_statistics()
        logger.info(f"✅ Firestore: {stats.get('verified_experiments', 0)} verified experiments")
    
    if not storage_service.is_available():
        logger.error("❌ Firebase Storage not available - CRITICAL")
    else:
        logger.info("✅ Firebase Storage connected")
    
    # 3. MODEL LOADING STRATEGY: Firebase Storage ONLY
    if not TF_AVAILABLE or not feature_encoder:
        logger.warning("⚠️ TensorFlow or encoder unavailable, using static algorithm")
        transfer_model = None
        logger.info("="*80)
        return
    
    local_model_path = "models/diode_laser_transfer_v1.h5"
    model_loaded = False
    
    # ===== ONLY SOURCE: Firebase Storage =====
    if storage_service.is_available():
        logger.info("🔍 Checking Firebase Storage for model...")
        
        if storage_service.model_exists_in_storage():
            logger.info("📦 Model found in Firebase Storage, downloading...")
            
            # Download to temp location
            if storage_service.load_model_from_storage(local_model_path):
                transfer_model = get_transfer_model(local_model_path)
                model_loaded = True
                logger.info("✅ Model loaded from Firebase Storage")
                
                # Show metadata
                metadata = storage_service.get_model_metadata()
                if metadata:
                    logger.info(f"   📊 Size: {metadata['size_mb']:.2f} MB")
                    logger.info(f"   📅 Updated: {metadata['updated']}")
            else:
                logger.error("❌ Failed to download model from Firebase Storage")
        else:
            logger.warning("⚠️ Model NOT found in Firebase Storage")
    else:
        logger.error("❌ Firebase Storage not available")
    
    # ===== If no model in Firebase, create NEW and train =====
    if not model_loaded:
        logger.info("🆕 No model in Firebase Storage, creating fresh model...")
        transfer_model = get_transfer_model()  # New untrained model
        logger.info("✅ Fresh model architecture created (UNTRAINED)")
        
        # Try to train immediately if data available
        if firebase.is_available():
            stats = firebase.get_statistics()
            verified_count = stats.get('verified_experiments', 0)
            
            if verified_count >= 50:
                logger.info(f"📊 Sufficient data ({verified_count} experiments), training now...")
                
                try:
                    training_data = firebase.get_training_data_for_transfer_learning(limit=500)
                    
                    if len(training_data) >= 30:
                        X, y_power, y_speed, y_passes = feature_encoder.encode_batch(training_data)
                        logger.info(f"   📊 Training with {len(X)} samples")
                        
                        # Train from scratch
                        os.makedirs("models", exist_ok=True)
                        transfer_model.train(X, y_power, y_speed, y_passes, 
                                           epochs=100, save_path=local_model_path)
                        
                        logger.info("✅ Training completed")
                        
                        # UPLOAD TO FIREBASE (PRIMARY STORAGE)
                        if storage_service.is_available():
                            logger.info("📤 Uploading trained model to Firebase Storage...")
                            
                            if storage_service.save_model_to_storage(local_model_path):
                                logger.info("✅ Model uploaded to Firebase Storage")
                                logger.info("   🎯 Firebase is now the single source of truth")
                            else:
                                logger.error("❌ Failed to upload to Firebase Storage")
                    else:
                        logger.warning(f"⚠️ Only {len(training_data)} samples, need 30+")
                
                except Exception as e:
                    logger.error(f"❌ Training failed: {e}")
                    logger.exception("Full error:")
            else:
                logger.warning(f"⚠️ Insufficient data: {verified_count} experiments (need 50+)")
                logger.info("   ℹ️ Model will use static algorithm until more data available")
    
    # 4. Online learning (optional)
    try:
        learner = get_online_learner()
        if learner.should_update():
            logger.info("🔄 Running online learning update...")
            learner.update_material_statistics()
    except Exception as e:
        logger.warning(f"⚠️ Online learning failed: {e}")
    
    logger.info("="*80)
    logger.info("🎯 STRATEGY: Firebase Storage is the single source of truth")
    logger.info(f"📊 Model Status: {'TRAINED' if (transfer_model and transfer_model.is_trained) else 'UNTRAINED'}")
    logger.info(f"📦 Model in Firebase: {storage_service.model_exists_in_storage() if storage_service.is_available() else 'Unknown'}")
    logger.info("="*80)


@app.on_event("shutdown")
async def shutdown_event():
    """Cleanup"""
    logger.info("👋 LaserTuner ML API Shutting down...")


# ============= MAIN =============

if __name__ == "__main__":
    import uvicorn
    port = int(os.getenv("PORT", 8000))
    host = os.getenv("HOST", "0.0.0.0")
    logger.info(f"Starting API on {host}:{port}")
    uvicorn.run("main:app", host=host, port=port, 
                reload=os.getenv("ENV") == "development", log_level="info")