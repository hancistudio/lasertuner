# -*- coding: utf-8 -*-
"""
LaserTuner ML API v3.0 - DIODE LASER EDITION
Backend API for Diode Laser Machines (2W-40W)
"""
from online_learning_service import get_online_learner 
from fastapi import FastAPI, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from pydantic import BaseModel, Field, validator
from typing import List, Dict, Optional
import logging
import os
from datetime import datetime
from dotenv import load_dotenv

# Import our services
from firebase_service import get_firebase_service
from ml_prediction import get_ml_service

# Load environment variables
load_dotenv()

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[logging.StreamHandler()]
)
logger = logging.getLogger(__name__)

# Initialize FastAPI app
app = FastAPI(
    title="LaserTuner ML API - Diode Laser Edition",
    version="3.0.0-diode",
    description="AI-powered diode laser cutting parameter prediction (2W-40W)"
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
        # Diode lazer için uygun malzemeler
        valid_materials = {
            'ahşap', 'ahsap', 'wood',
            'mdf',
            'karton', 'cardboard',
            'deri', 'leather',
            'keçe', 'felt',
            'kumaş', 'fabric', 'kumas',
            'kağıt', 'kagit', 'paper',
            'köpük', 'kopuk', 'foam',
            'mantar', 'cork'
        }
        
        if v.lower() not in valid_materials:
            raise ValueError(
                f"Diode lazer için desteklenmeyen malzeme: {v}. "
                f"Desteklenen malzemeler: Ahşap, MDF, Karton, Deri, Keçe, Kumaş, Kağıt, Köpük, Mantar"
            )
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
    material = material.lower()
    
    # Format: {base_power_%, power_per_mm, base_speed, speed_per_mm, base_passes, passes_per_mm}
    params = {
        # Ahşap - en yaygın kullanım
        'ahşap': {'base_power': 80, 'power_mult': 4.0, 'base_speed': 300, 'speed_mult': 30, 'base_passes': 2, 'passes_mult': 0.5},
        'ahsap': {'base_power': 80, 'power_mult': 4.0, 'base_speed': 300, 'speed_mult': 30, 'base_passes': 2, 'passes_mult': 0.5},
        'wood': {'base_power': 80, 'power_mult': 4.0, 'base_speed': 300, 'speed_mult': 30, 'base_passes': 2, 'passes_mult': 0.5},
        
        # MDF - ahşaba benzer
        'mdf': {'base_power': 85, 'power_mult': 4.5, 'base_speed': 280, 'speed_mult': 35, 'base_passes': 2, 'passes_mult': 0.6},
        
        # Karton - kolay kesilir
        'karton': {'base_power': 50, 'power_mult': 3.0, 'base_speed': 400, 'speed_mult': 25, 'base_passes': 1, 'passes_mult': 0.3},
        'cardboard': {'base_power': 50, 'power_mult': 3.0, 'base_speed': 400, 'speed_mult': 25, 'base_passes': 1, 'passes_mult': 0.3},
        
        # Deri - orta zorluk
        'deri': {'base_power': 70, 'power_mult': 3.5, 'base_speed': 350, 'speed_mult': 28, 'base_passes': 1, 'passes_mult': 0.4},
        'leather': {'base_power': 70, 'power_mult': 3.5, 'base_speed': 350, 'speed_mult': 28, 'base_passes': 1, 'passes_mult': 0.4},
        
        # Keçe - kolay
        'keçe': {'base_power': 60, 'power_mult': 2.5, 'base_speed': 380, 'speed_mult': 20, 'base_passes': 1, 'passes_mult': 0.2},
        'felt': {'base_power': 60, 'power_mult': 2.5, 'base_speed': 380, 'speed_mult': 20, 'base_passes': 1, 'passes_mult': 0.2},
        
        # Kumaş - çok kolay
        'kumaş': {'base_power': 45, 'power_mult': 2.0, 'base_speed': 420, 'speed_mult': 15, 'base_passes': 1, 'passes_mult': 0.1},
        'kumas': {'base_power': 45, 'power_mult': 2.0, 'base_speed': 420, 'speed_mult': 15, 'base_passes': 1, 'passes_mult': 0.1},
        'fabric': {'base_power': 45, 'power_mult': 2.0, 'base_speed': 420, 'speed_mult': 15, 'base_passes': 1, 'passes_mult': 0.1},
        
        # Kağıt - çok kolay
        'kağıt': {'base_power': 40, 'power_mult': 1.5, 'base_speed': 450, 'speed_mult': 10, 'base_passes': 1, 'passes_mult': 0.1},
        'kagit': {'base_power': 40, 'power_mult': 1.5, 'base_speed': 450, 'speed_mult': 10, 'base_passes': 1, 'passes_mult': 0.1},
        'paper': {'base_power': 40, 'power_mult': 1.5, 'base_speed': 450, 'speed_mult': 10, 'base_passes': 1, 'passes_mult': 0.1},
        
        # Köpük - kolay
        'köpük': {'base_power': 55, 'power_mult': 2.0, 'base_speed': 400, 'speed_mult': 18, 'base_passes': 1, 'passes_mult': 0.2},
        'kopuk': {'base_power': 55, 'power_mult': 2.0, 'base_speed': 400, 'speed_mult': 18, 'base_passes': 1, 'passes_mult': 0.2},
        'foam': {'base_power': 55, 'power_mult': 2.0, 'base_speed': 400, 'speed_mult': 18, 'base_passes': 1, 'passes_mult': 0.2},
        
        # Mantar - orta
        'mantar': {'base_power': 65, 'power_mult': 3.0, 'base_speed': 360, 'speed_mult': 22, 'base_passes': 1, 'passes_mult': 0.3},
        'cork': {'base_power': 65, 'power_mult': 3.0, 'base_speed': 360, 'speed_mult': 22, 'base_passes': 1, 'passes_mult': 0.3},
    }
    
    # Default values
    return params.get(material, {
        'base_power': 75, 'power_mult': 3.5, 'base_speed': 320, 
        'speed_mult': 25, 'base_passes': 2, 'passes_mult': 0.4
    })


def calculate_diode_cutting_params(material: str, thickness: float) -> ProcessParams:
    """Calculate cutting parameters for diode laser"""
    params = get_diode_material_params(material)
    
    # Calculate power (percentage)
    power = params['base_power'] + (thickness * params['power_mult'])
    power = round(max(10, min(100, power)), 1)
    
    # Calculate speed (mm/min)
    speed = params['base_speed'] - (thickness * params['speed_mult'])
    speed = round(max(50, min(500, speed)), 0)
    
    # Calculate passes
    passes = params['base_passes'] + int(thickness * params['passes_mult'])
    passes = max(1, min(20, passes))
    
    return ProcessParams(power=power, speed=speed, passes=passes)


def calculate_diode_engraving_params(material: str, thickness: float) -> ProcessParams:
    """Calculate engraving parameters for diode laser"""
    params = get_diode_material_params(material)
    
    # Engraving uses lower power and faster speed
    power = (params['base_power'] * 0.5) + (thickness * 1.5)
    power = round(max(10, min(100, power)), 1)
    
    speed = params['base_speed'] + 100  # Faster for engraving
    speed = round(max(100, min(500, speed)), 0)
    
    passes = 1  # Usually single pass for engraving
    
    return ProcessParams(power=power, speed=speed, passes=passes)


def calculate_diode_scoring_params(material: str, thickness: float) -> ProcessParams:
    """Calculate scoring parameters for diode laser"""
    params = get_diode_material_params(material)
    
    # Scoring is between engraving and cutting
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
        service="LaserTuner ML API - Diode Edition",
        version="3.0.0-diode",
        laserType="Diode Laser",
        powerRange="2W - 40W",
        timestamp=datetime.utcnow().isoformat(),
        firebase_status="connected" if firebase.is_available() else "disconnected",
        total_experiments=stats.get('total_experiments', 0)
    )


@app.get("/health", response_model=HealthResponse)
async def health_check():
    """Health check with Firebase status"""
    firebase = get_firebase_service()
    stats = firebase.get_statistics() if firebase.is_available() else {}
    
    return HealthResponse(
        status="healthy",
        service="LaserTuner ML API - Diode Edition",
        version="3.0.0-diode",
        laserType="Diode Laser",
        powerRange="2W - 40W",
        timestamp=datetime.utcnow().isoformat(),
        firebase_status="connected" if firebase.is_available() else "disconnected",
        total_experiments=stats.get('total_experiments', 0)
    )


@app.get("/statistics")
async def get_statistics():
    """Get database statistics"""
    firebase = get_firebase_service()
    
    if not firebase.is_available():
        return {
            "status": "firebase_unavailable",
            "message": "Firebase bağlantısı mevcut değil",
            "using_fallback": True
        }
    
    stats = firebase.get_statistics()
    return stats


@app.post("/predict", response_model=PredictionResponse)
async def predict(request: PredictionRequest):
    """Predict diode laser cutting parameters using REAL USER DATA"""
    start_time = datetime.now()
    
    try:
        logger.info(
            f"🔍 Diode Laser Prediction: {request.machineBrand} {request.laserPower}W, "
            f"{request.materialType} {request.materialThickness}mm, "
            f"processes: {request.processes}"
        )
        
        # Warnings for diode laser limitations
        warnings = []
        
        # Check thickness
        if request.materialThickness > 8:
            warnings.append(
                f"⚠️ {request.materialThickness}mm kalınlık diode lazer için zorlu olabilir. "
                f"En iyi sonuç için 3-5mm önerilir."
            )
        
        # Check power for thick materials
        if request.materialThickness > 5 and request.laserPower < 20:
            warnings.append(
                f"⚠️ {request.laserPower}W güç {request.materialThickness}mm kesim için düşük olabilir. "
                f"Daha fazla geçiş gerekebilir."
            )
        
        # Get services
        firebase = get_firebase_service()
        ml_service = get_ml_service()
        
        predictions = {}
        total_data_points = 0
        max_confidence = 0.0
        all_notes = []
        data_sources = set()
        
        # Try to get similar experiments from Firebase
        similar_experiments = []
        if firebase.is_available():
            similar_experiments = firebase.get_similar_experiments(
                material_type=request.materialType,
                thickness=request.materialThickness,
                thickness_tolerance=1.5  # Tighter tolerance for diode
            )
            logger.info(f"📊 Found {len(similar_experiments)} similar experiments")
        
        # Calculate parameters for each process
        for process_type in request.processes:
            if similar_experiments:
                ml_result = ml_service.predict_from_data(
                    experiments=similar_experiments,
                    process_type=process_type,
                    material_type=request.materialType,
                    thickness=request.materialThickness,
                    target_power=request.laserPower
                )
                
                params_dict, confidence, notes = ml_result
                
                if params_dict:
                    # Success! Using real data
                    predictions[process_type] = ProcessParams(**params_dict)
                    total_data_points = len(similar_experiments)
                    max_confidence = max(max_confidence, confidence)
                    all_notes.append(notes)
                    data_sources.add("user_data")
                    logger.info(
                        f"✅ {process_type}: Using ML prediction (confidence: {confidence})"
                    )
                    continue
            
            # Fallback to diode-specific algorithm
            logger.info(
                f"⚠️ {process_type}: Insufficient data, using diode laser algorithm"
            )
            
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
            data_sources.add("static_algorithm")
        
        # Determine final confidence and notes
        if total_data_points > 0:
            confidence_score = max_confidence
            final_notes = " | ".join(all_notes)
            data_source = "hybrid" if "static_algorithm" in data_sources else "user_data"
        else:
            confidence_score = 0.55
            final_notes = (
                "⚠️ Yetersiz topluluk verisi, diode lazer algoritması kullanıldı. "
                "Daha iyi sonuçlar için benzer deneyler ekleyin!"
            )
            data_source = "static_algorithm"
        
        # Create response
        response = PredictionResponse(
            predictions=predictions,
            confidenceScore=confidence_score,
            notes=final_notes,
            dataPointsUsed=total_data_points,
            dataSource=data_source,
            warnings=warnings
        )
        
        duration = (datetime.now() - start_time).total_seconds()
        logger.info(
            f"✅ Prediction complete: {len(predictions)} processes, "
            f"source: {data_source}, "
            f"data_points: {total_data_points}, "
            f"confidence: {confidence_score:.2f}, "
            f"duration: {duration:.3f}s"
        )
        
        return response
        
    except ValueError as e:
        logger.warning(f"❌ Validation error: {str(e)}")
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        logger.exception(f"❌ Unexpected error: {str(e)}")
        raise HTTPException(
            status_code=500,
            detail="Tahmin sırasında bir hata oluştu."
        )


@app.get("/test")
async def test_endpoint():
    """Test endpoint with Firebase status"""
    firebase = get_firebase_service()
    stats = firebase.get_statistics() if firebase.is_available() else {}
    
    return {
        "status": "ok",
        "version": "3.0.0-diode",
        "laser_type": "Diode Laser",
        "power_range": "2W - 40W",
        "message": "Diode Laser API çalışıyor!",
        "firebase_connected": firebase.is_available(),
        "total_experiments": stats.get('total_experiments', 0),
        "verified_experiments": stats.get('verified_experiments', 0),
        "supported_materials": [
            "Ahşap (Wood)", "MDF", "Karton (Cardboard)", "Deri (Leather)",
            "Keçe (Felt)", "Kumaş (Fabric)", "Kağıt (Paper)", 
            "Köpük (Foam)", "Mantar (Cork)"
        ],
        "example_request": {
            "machineBrand": "xTool D1 Pro",
            "laserPower": 20,
            "materialType": "Ahşap",
            "materialThickness": 3,
            "processes": ["cutting", "engraving"]
        }
    }


@app.get("/materials")
async def get_supported_materials():
    """Get list of supported materials for diode laser"""
    return {
        "supported_materials": {
            "organic": [
                {"name": "Ahşap (Wood)", "turkish": "Ahşap", "english": "Wood", "max_thickness": 8},
                {"name": "MDF", "turkish": "MDF", "english": "MDF", "max_thickness": 6},
                {"name": "Karton (Cardboard)", "turkish": "Karton", "english": "Cardboard", "max_thickness": 5},
                {"name": "Deri (Leather)", "turkish": "Deri", "english": "Leather", "max_thickness": 5},
                {"name": "Keçe (Felt)", "turkish": "Keçe", "english": "Felt", "max_thickness": 4},
                {"name": "Kumaş (Fabric)", "turkish": "Kumaş", "english": "Fabric", "max_thickness": 3},
                {"name": "Kağıt (Paper)", "turkish": "Kağıt", "english": "Paper", "max_thickness": 2},
                {"name": "Köpük (Foam)", "turkish": "Köpük", "english": "Foam", "max_thickness": 10},
                {"name": "Mantar (Cork)", "turkish": "Mantar", "english": "Cork", "max_thickness": 6}
            ]
        },
        "not_supported": [
            "Akrilik/Plexiglass (CO2 lazer gerektirir)",
            "Metal (Fiber lazer gerektirir)",
            "Cam (Fiber lazer gerektirir)",
            "Seramik"
        ],
        "notes": [
            "Diode lazerler 2W-40W güç aralığında çalışır",
            "En iyi sonuçlar 3-5mm kalınlıkta alınır",
            "8mm üzeri kesim çok zordur ve önerilmez",
            "Organik malzemeler (ahşap, deri, kağıt) en iyi sonuçları verir"
        ]
    }


# ============= STARTUP/SHUTDOWN =============

@app.on_event("startup")
async def startup_event():
    """Initialize services on startup"""
    logger.info("="*50)
    logger.info("🚀 LaserTuner ML API v3.0 - DIODE LASER EDITION")
    logger.info("⚡ Power Range: 2W - 40W")
    logger.info(f"Allowed Origins: {ALLOWED_ORIGINS}")
    
    # Initialize Firebase
    firebase = get_firebase_service()
    if firebase.is_available():
        stats = firebase.get_statistics()
        logger.info(f"✅ Firebase connected")
        logger.info(f"📊 Total experiments: {stats.get('total_experiments', 0)}")
        logger.info(f"✅ Verified experiments: {stats.get('verified_experiments', 0)}")
        
        # ✨ YENİ: Online learning başlat
        try:
            learner = get_online_learner()
            if learner.should_update():
                logger.info("🔄 Running online learning update...")
                learner.update_material_statistics()
        except Exception as e:
            logger.warning(f"⚠️ Online learning initialization failed: {e}")
    else:
        logger.warning("⚠️ Firebase not available - using diode laser algorithms only")
    
    logger.info("="*50)


@app.on_event("shutdown")
async def shutdown_event():
    """Cleanup on shutdown"""
    logger.info("👋 LaserTuner ML API Shutting down...")


# ============= MAIN =============

if __name__ == "__main__":
    import uvicorn
    
    port = int(os.getenv("PORT", 8000))
    host = os.getenv("HOST", "0.0.0.0")
    
    logger.info(f"Starting Diode Laser API on {host}:{port}")
    
    uvicorn.run(
        "main:app",
        host=host,
        port=port,
        reload=os.getenv("ENV", "production") == "development",
        log_level="info"
    )