# -*- coding: utf-8 -*-
"""
LaserTuner ML API v3.1 - FULL TRANSFER LEARNING EDITION
Backend API for Diode Laser Machines (2W-40W)
🎯 IMAGE + NUMERICAL FEATURES + ONLINE LEARNING + DATA QUALITY
"""
import sys
import io
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

from online_learning_service import get_online_learner 
from ml_feature_engineering import get_feature_encoder
from ml_transfer_model import get_transfer_model, TF_AVAILABLE
from image_preprocessing_service import get_image_preprocessor
from data_quality_service import get_quality_service
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
image_preprocessor = None
quality_service = None

# Initialize FastAPI app
app = FastAPI(
    title="LaserTuner ML API - Full Transfer Learning Edition",
    version="3.1.0-full-transfer-learning",
    description="AI-powered diode laser parameter prediction with IMAGE+NUMERICAL features + Online Learning"
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
    laserPower: float = Field(..., ge=2, le=40, description="Laser power in Watts (2-40W)")
    materialType: str = Field(..., min_length=1, max_length=50)
    materialThickness: float = Field(..., gt=0, le=10, description="Thickness in mm (max 10mm for diode)")
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
        service="LaserTuner ML API - Full Transfer Learning Edition",
        version="3.1.0-full-transfer-learning",
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
        service="LaserTuner ML API - Full Transfer Learning Edition",
        version="3.1.0-full-transfer-learning",
        laserType="Diode Laser",
        powerRange="2W - 40W",
        timestamp=datetime.utcnow().isoformat(),
        firebase_status="connected" if firebase.is_available() else "disconnected",
        total_experiments=stats.get('total_experiments', 0)
    )


@app.post("/predict", response_model=PredictionResponse)
async def predict(request: PredictionRequest):
    """
    🤖 FULL TRANSFER LEARNING PREDICTION
    
    Flow:
    1. Try transfer learning model (IMAGE + NUMERICAL features)
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
                logger.info("🤖 Using trained transfer learning model (image+numerical)...")
                
                for process_type in request.processes:
                    # Encode numerical features (9 features)
                    features = feature_encoder.encode(
                        material_type=request.materialType,
                        thickness=request.materialThickness,
                        laser_power=request.laserPower,
                        process_type=process_type
                    )
                    
                    # Image features (dummy for prediction - no photo available)
                    X_img = None
                    if image_preprocessor and image_preprocessor.is_available():
                        X_img = image_preprocessor.create_dummy_batch(1)
                    
                    # Predict (normalized 0-1 outputs)
                    X_num = features.reshape(1, -1)
                    power_norm, speed_norm, passes_norm = transfer_model.predict(X_num, X_img)
                    
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
                notes = "🤖 Transfer learning model (image+numerical features from Firebase)"
                
            except Exception as e:
                logger.warning(f"⚠️ Transfer learning prediction failed: {e}")
                logger.exception("Full error:")
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
    """Test endpoint with full system info"""
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
    
    # Image preprocessing status
    image_info = {}
    if image_preprocessor:
        image_info = {
            'available': image_preprocessor.is_available(),
            'stats': image_preprocessor.get_stats() if image_preprocessor.is_available() else None
        }
    
    # Online learning status
    online_info = {}
    try:
        learner = get_online_learner()
        online_info = {
            'last_update': learner.last_update.isoformat(),
            'material_stats_count': len(learner.material_stats)
        }
    except:
        online_info = {'status': 'error'}
    
    return {
        "status": "ok",
        "version": "3.1.0-full-transfer-learning",
        "strategy": "Full Transfer Learning: Image+Numerical+Online",
        "transfer_learning_enabled": TF_AVAILABLE and transfer_model is not None,
        "transfer_learning_trained": transfer_model.is_trained if transfer_model else False,
        "firebase_firestore_connected": firebase.is_available(),
        "firebase_storage_connected": storage_service.is_available(),
        "model_storage": model_info,
        "image_preprocessing": image_info,
        "online_learning": online_info,
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
    
    ✅ UPDATED: Now includes image loading + data quality
    
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
        raw_training_data = firebase.get_training_data_for_transfer_learning(limit=500)
        
        if len(raw_training_data) < 30:
            raise HTTPException(
                status_code=400, 
                detail=f"Insufficient data for fine-tuning: {len(raw_training_data)} samples (need 30+)"
            )
        
        # ✅ 3. DATA QUALITY PIPELINE
        logger.info("🛡️ Applying data quality pipeline...")
        quality_service = get_quality_service()
        
        clean_data, outliers = quality_service.detect_outliers(raw_training_data, method='iqr', threshold=1.5)
        logger.info(f"   Removed {len(outliers)} outliers")
        
        augmented_data = quality_service.augment_data(clean_data, augmentation_factor=2)
        logger.info(f"   Augmented: {len(clean_data)} → {len(augmented_data)}")
        
        # ✅ 4. ENCODE DATA
        feature_encoder = get_feature_encoder()
        X_num, y_power, y_speed, y_passes = feature_encoder.encode_batch(augmented_data)
        logger.info(f"✅ Encoded {len(X_num)} training samples")
        
        # ✅ 5. LOAD IMAGES (if available)
        X_img = None
        image_preprocessor = get_image_preprocessor()
        
        if image_preprocessor.is_available():
            logger.info("📸 Loading images...")
            # Try to get experiment docs with photo URLs
            firebase_experiments = []
            for sample in augmented_data[:200]:
                exp_id = sample.get('id')
                if exp_id:
                    try:
                        exp_doc = firebase.db.collection('experiments').document(exp_id).get()
                        if exp_doc.exists:
                            firebase_experiments.append(exp_doc.to_dict())
                    except:
                        continue
            
            if len(firebase_experiments) > 0:
                X_img = image_preprocessor.load_batch_images(
                    firebase_experiments, augment=True, fallback_to_zeros=True
                )
                logger.info(f"✅ Loaded {len(X_img)} images")
        
        # 6. Fine-tune
        logger.info("🔄 Fine-tuning model...")
        history = transfer_model.fine_tune(
            X_num, y_power, y_speed, y_passes, 
            X_images=X_img,
            freeze_cnn=True,
            epochs=50
        )
        
        # 7. Save locally (temporary)
        local_model_path = "models/diode_laser_transfer_v1.h5"
        os.makedirs("models", exist_ok=True)
        transfer_model.save_model(local_model_path)
        
        # 8. Upload to Firebase (CRITICAL)
        logger.info("📤 Uploading fine-tuned model to Firebase Storage...")
        success = storage_service.save_model_to_storage(local_model_path)
        
        if not success:
            raise HTTPException(status_code=500, detail="Failed to upload to Firebase Storage")
        
        # 9. Get metadata
        metadata = storage_service.get_model_metadata()
        
        logger.info("✅ Fine-tuning complete and uploaded to Firebase")
        
        return {
            "status": "success",
            "message": "Model fine-tuned with full pipeline and uploaded",
            "training_samples": len(X_num),
            "images_used": X_img is not None and len(X_img) > 0,
            "outliers_removed": len(outliers),
            "augmentation_factor": 2,
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
    Admin endpoint: Train completely new model with FULL PIPELINE
    
    ✅ UPDATED: Image loading + Data quality + Online learning ready
    
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
        raw_training_data = firebase.get_training_data_for_transfer_learning(limit=500)
        
        if len(raw_training_data) < 50:
            raise HTTPException(
                status_code=400, 
                detail=f"Insufficient data for training: {len(raw_training_data)} samples (need 50+)"
            )
        
        # ✅ 2. DATA QUALITY PIPELINE
        logger.info("🛡️ Applying data quality pipeline...")
        quality_service = get_quality_service()
        
        # Outlier detection
        clean_data, outliers = quality_service.detect_outliers(
            raw_training_data, 
            method='iqr', 
            threshold=1.5
        )
        logger.info(f"   Removed {len(outliers)} outliers")
        
        # Data augmentation
        augmented_data = quality_service.augment_data(clean_data, augmentation_factor=2)
        logger.info(f"   Augmented: {len(clean_data)} → {len(augmented_data)}")
        
        final_training_data = augmented_data
        
        # ✅ 3. ENCODE NUMERICAL FEATURES
        feature_encoder = get_feature_encoder()
        X_num, y_power, y_speed, y_passes = feature_encoder.encode_batch(final_training_data)
        logger.info(f"✅ Encoded {len(X_num)} training samples (numerical)")
        
        # ✅ 4. LOAD IMAGES
        X_img = None
        image_preprocessor = get_image_preprocessor()
        
        if image_preprocessor.is_available():
            logger.info("📸 Loading images for training...")
            
            # Get experiment docs with photo URLs
            firebase_experiments = []
            for sample in final_training_data[:200]:  # First 200
                exp_id = sample.get('id')
                if exp_id:
                    try:
                        exp_doc = firebase.db.collection('experiments').document(exp_id).get()
                        if exp_doc.exists:
                            firebase_experiments.append(exp_doc.to_dict())
                    except:
                        continue
            
            if len(firebase_experiments) > 0:
                X_img = image_preprocessor.load_batch_images(
                    firebase_experiments,
                    augment=True,
                    fallback_to_zeros=True
                )
                logger.info(f"✅ Loaded {len(X_img)} images")
            else:
                logger.warning("⚠️ No images available, using numerical features only")
        
        # ✅ 5. CREATE MODEL (with or without images)
        use_images = X_img is not None and len(X_img) > 0
        logger.info(f"🆕 Creating model (images={'ON' if use_images else 'OFF'})...")
        
        transfer_model = get_transfer_model(use_images=use_images)
        
        # ✅ 6. TRAIN FROM SCRATCH
        local_model_path = "models/diode_laser_transfer_v1.h5"
        os.makedirs("models", exist_ok=True)
        
        logger.info("🔄 Training model from scratch...")
        history = transfer_model.train(
            X_num, y_power, y_speed, y_passes, 
            X_images=X_img,
            epochs=100, 
            save_path=local_model_path
        )
        
        # ✅ 7. UPLOAD TO FIREBASE
        logger.info("📤 Uploading trained model to Firebase Storage...")
        success = storage_service.save_model_to_storage(local_model_path)
        
        if not success:
            raise HTTPException(status_code=500, detail="Failed to upload to Firebase Storage")
        
        # ✅ 8. GET METADATA
        metadata = storage_service.get_model_metadata()
        
        logger.info("✅ Training complete and uploaded to Firebase")
        
        return {
            "status": "success",
            "message": "Model trained with full pipeline and uploaded",
            "training_samples": len(X_num),
            "images_used": use_images,
            "outliers_removed": len(outliers),
            "augmentation_factor": 2,
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
        use_images = image_preprocessor.is_available() if image_preprocessor else False
        transfer_model = get_transfer_model(local_model_path, use_images=use_images)
        
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


@app.post("/admin/trigger-online-update")
async def trigger_online_update():
    """
    ✅ NEW: Manually trigger online learning update
    
    Usage: POST /admin/trigger-online-update
    """
    try:
        learner = get_online_learner()
        learner.manual_update_trigger()
        
        history = learner.get_update_history(limit=5)
        
        return {
            "status": "success",
            "message": "Online learning update triggered",
            "recent_updates": history
        }
        
    except Exception as e:
        logger.exception("Online update error")
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/admin/online-learning-status")
async def online_learning_status():
    """
    ✅ NEW: Get online learning status
    
    Usage: GET /admin/online-learning-status
    """
    try:
        learner = get_online_learner()
        
        return {
            "last_update": learner.last_update.isoformat(),
            "next_update": (learner.last_update + learner.update_interval).isoformat(),
            "update_interval_days": learner.update_interval.days,
            "material_stats_count": len(learner.material_stats),
            "recent_updates": learner.get_update_history(limit=10),
            "scheduler_running": learner.scheduler is not None and learner.scheduler.running
        }
        
    except Exception as e:
        logger.exception("Status check error")
        raise HTTPException(status_code=500, detail=str(e))


# ============= STARTUP =============

@app.on_event("startup")
async def startup_event():
    """
    🚀 FULL TRANSFER LEARNING STARTUP
    
    Steps:
    1. Initialize all services (feature encoder, image preprocessor, quality service)
    2. Connect to Firebase (Firestore + Storage)
    3. Try to load model from Firebase Storage
    4. If not in Firebase, create new + train if data available
    5. Start online learning scheduler
    """
    global transfer_model, feature_encoder, image_preprocessor, quality_service
    
    logger.info("="*80)
    logger.info("🚀 LaserTuner ML API v3.1 - FULL TRANSFER LEARNING")
    logger.info("🎯 Features: IMAGE + NUMERICAL + ONLINE LEARNING + DATA QUALITY")
    logger.info("="*80)
    
    # ✅ 1. Initialize services
    try:
        feature_encoder = get_feature_encoder()
        logger.info("✅ Feature encoder: READY")
    except Exception as e:
        logger.error(f"❌ Feature encoder failed: {e}")
        feature_encoder = None
    
    try:
        image_preprocessor = get_image_preprocessor()
        if image_preprocessor.is_available():
            logger.info("✅ Image preprocessor: READY")
        else:
            logger.warning("⚠️ Image preprocessor: DISABLED (PIL not available)")
    except Exception as e:
        logger.error(f"❌ Image preprocessor failed: {e}")
        image_preprocessor = None
    
    try:
        quality_service = get_quality_service()
        logger.info("✅ Quality service: READY")
    except Exception as e:
        logger.error(f"❌ Quality service failed: {e}")
        quality_service = None
    
    # ✅ 2. Initialize Firebase
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
    
    # ✅ 3. MODEL LOADING
    if not TF_AVAILABLE or not feature_encoder:
        logger.warning("⚠️ TensorFlow or encoder unavailable, using static algorithm only")
        transfer_model = None
    else:
        local_model_path = "models/diode_laser_transfer_v1.h5"
        model_loaded = False
        
        # Try Firebase Storage
        if storage_service.is_available() and storage_service.model_exists_in_storage():
            logger.info("📦 Model found in Firebase Storage, downloading...")
            
            if storage_service.load_model_from_storage(local_model_path):
                use_images = image_preprocessor.is_available() if image_preprocessor else False
                transfer_model = get_transfer_model(local_model_path, use_images=use_images)
                model_loaded = True
                logger.info("✅ Model loaded from Firebase Storage")
                
                metadata = storage_service.get_model_metadata()
                if metadata:
                    logger.info(f"   📊 Size: {metadata['size_mb']:.2f} MB")
                    logger.info(f"   📅 Updated: {metadata['updated']}")
        
        # Create new if not exists
        if not model_loaded:
            logger.info("🆕 No model in Firebase, creating fresh model...")
            use_images = image_preprocessor.is_available() if image_preprocessor else False
            transfer_model = get_transfer_model(use_images=use_images)
            logger.info(f"✅ Fresh model created (images={'ON' if use_images else 'OFF'}, UNTRAINED)")
            
            # Auto-train if data available
            if firebase.is_available():
                stats = firebase.get_statistics()
                verified_count = stats.get('verified_experiments', 0)
                
                if verified_count >= 50:
                    logger.info(f"📊 Sufficient data ({verified_count} exp), auto-training...")
                    
                    try:
                        raw_data = firebase.get_training_data_for_transfer_learning(limit=500)
                        
                        if len(raw_data) >= 50:
                            # Data quality pipeline
                            if quality_service:
                                clean_data, _ = quality_service.detect_outliers(raw_data)
                                augmented = quality_service.augment_data(clean_data, 2)
                                training_data = augmented
                            else:
                                training_data = raw_data
                            
                            X_num, y_power, y_speed, y_passes = feature_encoder.encode_batch(training_data)
                            logger.info(f"   📊 Training with {len(X_num)} samples")
                            
                            # Images (optional)
                            X_img = None
                            if image_preprocessor and image_preprocessor.is_available():
                                firebase_exps = []
                                for s in training_data[:200]:
                                    if s.get('id'):
                                        try:
                                            doc = firebase.db.collection('experiments').document(s['id']).get()
                                            if doc.exists:
                                                firebase_exps.append(doc.to_dict())
                                        except:
                                            continue
                                
                                if firebase_exps:
                                    X_img = image_preprocessor.load_batch_images(firebase_exps, True, True)
                            
                            # Train
                            os.makedirs("models", exist_ok=True)
                            transfer_model.train(
                                X_num, y_power, y_speed, y_passes, 
                                X_images=X_img,
                                epochs=100, 
                                save_path=local_model_path
                            )
                            
                            logger.info("✅ Auto-training completed")
                            
                            # Upload to Firebase
                            if storage_service.is_available():
                                logger.info("📤 Uploading to Firebase Storage...")
                                if storage_service.save_model_to_storage(local_model_path):
                                    logger.info("✅ Model uploaded to Firebase Storage")
                                else:
                                    logger.error("❌ Failed to upload to Firebase Storage")
                    
                    except Exception as e:
                        logger.error(f"❌ Auto-training failed: {e}")
                        logger.exception("Full error:")
                else:
                    logger.warning(f"⚠️ Insufficient data: {verified_count} experiments (need 50+)")
    
    # ✅ 4. START ONLINE LEARNING SCHEDULER
    try:
        learner = get_online_learner()
        if learner.scheduler and learner.scheduler.running:
            logger.info("✅ Online learning scheduler: STARTED")
            logger.info(f"   📅 Next update: {(learner.last_update + learner.update_interval).isoformat()}")
        else:
            logger.warning("⚠️ Online learning scheduler: NOT RUNNING")
    except Exception as e:
        logger.warning(f"⚠️ Online learning scheduler failed: {e}")
    
    logger.info("="*80)
    logger.info(f"📊 Model Status: {'TRAINED' if (transfer_model and transfer_model.is_trained) else 'UNTRAINED'}")
    logger.info(f"🖼️ Image Features: {'ENABLED' if (image_preprocessor and image_preprocessor.is_available()) else 'DISABLED'}")
    logger.info(f"🔄 Online Learning: {'ACTIVE' if learner.scheduler else 'INACTIVE'}")
    logger.info(f"📦 Model in Firebase: {storage_service.model_exists_in_storage() if storage_service.is_available() else 'Unknown'}")
    logger.info("="*80)


@app.on_event("shutdown")
async def shutdown_event():
    """Cleanup"""
    logger.info("👋 LaserTuner ML API Shutting down...")
    
    # Stop scheduler
    try:
        learner = get_online_learner()
        learner.shutdown()
        logger.info("✅ Online learning scheduler stopped")
    except:
        pass


# ============= MAIN =============

if __name__ == "__main__":
    import uvicorn
    port = int(os.getenv("PORT", 8000))
    host = os.getenv("HOST", "0.0.0.0")
    logger.info(f"Starting API on {host}:{port}")
    uvicorn.run("main:app", host=host, port=port, 
                reload=os.getenv("ENV") == "development", log_level="info")