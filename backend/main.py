# -*- coding: utf-8 -*-
"""
LaserTuner ML API v3.0
Backend API with REAL ML predictions from user data
"""

from fastapi import FastAPI, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from pydantic import BaseModel, Field, validator
from typing import List, Dict, Optional
import logging
import os
from datetime import datetime
from dotenv import load_dotenv

# Import our new services
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
    title="LaserTuner ML API",
    version="3.0.0",
    description="AI-powered laser cutting parameter prediction with real user data"
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
    """Process parameters for laser operations"""
    power: float = Field(..., ge=10, le=100)
    speed: float = Field(..., ge=50, le=1000)
    passes: int = Field(..., ge=1, le=10)


class PredictionRequest(BaseModel):
    """Request model for parameter prediction"""
    machineBrand: str = Field(..., min_length=1, max_length=100)
    laserPower: float = Field(..., gt=0, le=200)
    materialType: str = Field(..., min_length=1, max_length=50)
    materialThickness: float = Field(..., gt=0, le=50)
    processes: List[str] = Field(..., min_items=1, max_items=3)

    @validator('processes')
    def validate_processes(cls, v):
        valid_processes = {'cutting', 'engraving', 'scoring'}
        invalid = [p for p in v if p not in valid_processes]
        if invalid:
            raise ValueError(f"Invalid process types: {invalid}")
        if len(v) != len(set(v)):
            raise ValueError("Duplicate process types not allowed")
        return v


class PredictionResponse(BaseModel):
    """Response model for predictions"""
    predictions: Dict[str, ProcessParams]
    confidenceScore: float = Field(..., ge=0, le=1)
    notes: str
    dataPointsUsed: int = Field(default=0, ge=0)
    dataSource: str = Field(default="static_algorithm")  # NEW


class HealthResponse(BaseModel):
    """Health check response"""
    status: str
    service: str
    version: str
    timestamp: str
    firebase_status: str = "unknown"  # NEW
    total_experiments: int = 0  # NEW


# ============= UTILITY FUNCTIONS (Fallback) =============

def get_material_cutting_params(material: str) -> tuple:
    """Get base cutting parameters for material"""
    material = material.lower()
    material_params = {
        'ahşap': (65, 3.0), 'ahsap': (65, 3.0), 'wood': (65, 3.0),
        'mdf': (70, 3.5),
        'plexiglass': (55, 2.5), 'akrilik': (55, 2.5), 'acrylic': (55, 2.5),
        'karton': (35, 2.0), 'cardboard': (35, 2.0),
        'deri': (40, 1.5), 'leather': (40, 1.5),
    }
    return material_params.get(material, (70, 3.0))


def get_material_cutting_speeds(material: str) -> tuple:
    """Get base cutting speeds for material"""
    material = material.lower()
    speed_params = {
        'ahşap': (320, 18), 'ahsap': (320, 18), 'wood': (320, 18),
        'mdf': (300, 20),
        'plexiglass': (380, 25), 'akrilik': (380, 25), 'acrylic': (380, 25),
        'karton': (450, 15), 'cardboard': (450, 15),
        'deri': (400, 12), 'leather': (400, 12),
    }
    return speed_params.get(material, (300, 20))


def calculate_cutting_params(material: str, thickness: float) -> ProcessParams:
    """Calculate cutting parameters (fallback)"""
    base_power, power_mult = get_material_cutting_params(material)
    base_speed, speed_mult = get_material_cutting_speeds(material)
    
    power = base_power + (thickness * power_mult)
    speed = base_speed - (thickness * speed_mult)
    passes = max(1, int(thickness / 4))
    
    power = round(max(10, min(100, power)), 1)
    speed = round(max(50, min(800, speed)), 0)
    passes = min(10, passes)
    
    return ProcessParams(power=power, speed=speed, passes=passes)


def calculate_engraving_params(material: str, thickness: float) -> ProcessParams:
    """Calculate engraving parameters (fallback)"""
    base_power = 40 + (thickness * 2)
    base_speed = 500 - (thickness * 15)
    
    power = round(max(10, min(100, base_power)), 1)
    speed = round(max(100, min(800, base_speed)), 0)
    
    return ProcessParams(power=power, speed=speed, passes=1)


def calculate_scoring_params(material: str, thickness: float) -> ProcessParams:
    """Calculate scoring parameters (fallback)"""
    base_power = 55 + (thickness * 2.5)
    base_speed = 400 - (thickness * 18)
    
    power = round(max(10, min(100, base_power)), 1)
    speed = round(max(80, min(700, base_speed)), 0)
    
    return ProcessParams(power=power, speed=speed, passes=1)


# ============= API ENDPOINTS =============

@app.get("/", response_model=HealthResponse)
async def root():
    """Root endpoint"""
    firebase = get_firebase_service()
    stats = firebase.get_statistics() if firebase.is_available() else {}
    
    return HealthResponse(
        status="healthy",
        service="LaserTuner ML API",
        version="3.0.0",
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
        service="LaserTuner ML API",
        version="3.0.0",
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
            "message": "Firebase connection not available",
            "using_fallback": True
        }
    
    stats = firebase.get_statistics()
    return stats


@app.post("/predict", response_model=PredictionResponse)
async def predict(request: PredictionRequest):
    """
    Predict laser cutting parameters using REAL USER DATA
    
    NEW: Now uses verified experiments from Firestore!
    Falls back to static algorithm if insufficient data.
    """
    start_time = datetime.now()
    
    try:
        logger.info(
            f"🔍 Prediction request: {request.materialType} "
            f"{request.materialThickness}mm, processes: {request.processes}"
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
                thickness_tolerance=2.0
            )
            logger.info(f"📊 Found {len(similar_experiments)} similar experiments")
        
        # Calculate parameters for each process
        for process_type in request.processes:
            if similar_experiments:
                # Try ML prediction from real data
                ml_result = ml_service.predict_from_data(
                    experiments=similar_experiments,
                    process_type=process_type,
                    material_type=request.materialType,
                    thickness=request.materialThickness
                )
                
                params_dict, confidence, notes = ml_result
                
                if params_dict:
                    # Success! Using real data
                    predictions[process_type] = ProcessParams(**params_dict)
                    total_data_points = len(similar_experiments)
                    max_confidence = max(max_confidence, confidence)
                    all_notes.append(f"{process_type.title()}: {notes}")
                    data_sources.add("user_data")
                    logger.info(f"✅ {process_type}: Using ML prediction (confidence: {confidence})")
                    continue
            
            # Fallback to static algorithm
            logger.info(f"⚠️ {process_type}: Insufficient data, using static algorithm")
            params = ml_service.get_fallback_prediction(
                material_type=request.materialType,
                thickness=request.materialThickness,
                process_type=process_type
            )
            predictions[process_type] = ProcessParams(**params)
            data_sources.add("static_algorithm")
        
        # Determine final confidence and notes
        if total_data_points > 0:
            confidence_score = max_confidence
            final_notes = " | ".join(all_notes)
            data_source = "hybrid" if "static_algorithm" in data_sources else "user_data"
        else:
            confidence_score = 0.50
            final_notes = (
                "⚠️ Yetersiz topluluk verisi, temel algoritma kullanıldı. "
                "Daha iyi sonuçlar için benzer deneyler ekleyin!"
            )
            data_source = "static_algorithm"
        
        # Create response
        response = PredictionResponse(
            predictions=predictions,
            confidenceScore=confidence_score,
            notes=final_notes,
            dataPointsUsed=total_data_points,
            dataSource=data_source
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
        "version": "3.0.0",
        "message": "API is working with ML predictions!",
        "firebase_connected": firebase.is_available(),
        "total_experiments": stats.get('total_experiments', 0),
        "verified_experiments": stats.get('verified_experiments', 0),
        "example_request": {
            "machineBrand": "Epilog Laser Fusion Pro",
            "laserPower": 100,
            "materialType": "Ahşap",
            "materialThickness": 5,
            "processes": ["cutting", "engraving"]
        }
    }


# ============= STARTUP/SHUTDOWN =============

@app.on_event("startup")
async def startup_event():
    """Initialize services on startup"""
    logger.info("="*50)
    logger.info("🚀 LaserTuner ML API v3.0 Starting...")
    logger.info(f"Allowed Origins: {ALLOWED_ORIGINS}")
    
    # Initialize Firebase
    firebase = get_firebase_service()
    if firebase.is_available():
        stats = firebase.get_statistics()
        logger.info(f"✅ Firebase connected")
        logger.info(f"📊 Total experiments: {stats.get('total_experiments', 0)}")
        logger.info(f"✅ Verified experiments: {stats.get('verified_experiments', 0)}")
    else:
        logger.warning("⚠️ Firebase not available - using fallback algorithms only")
    
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
    
    logger.info(f"Starting server on {host}:{port}")
    
    uvicorn.run(
        "main:app",
        host=host,
        port=port,
        reload=os.getenv("ENV", "production") == "development",
        log_level="info"
    )