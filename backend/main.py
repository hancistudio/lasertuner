# -*- coding: utf-8 -*-
"""
LaserTuner ML API
Backend API for laser cutting parameter predictions
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

# Load environment variables
load_dotenv()

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

# Initialize FastAPI app
app = FastAPI(
    title="LaserTuner ML API",
    version="2.0.0",
    description="AI-powered laser cutting parameter prediction service"
)

# CORS Configuration - Read from environment
# Production: Netlify, Local: Flutter web, Chrome test
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
    power: float = Field(..., ge=10, le=100, description="Laser power percentage (10-100)")
    speed: float = Field(..., ge=50, le=1000, description="Speed in mm/s (50-1000)")
    passes: int = Field(..., ge=1, le=10, description="Number of passes (1-10)")

    class Config:
        schema_extra = {
            "example": {
                "power": 75.5,
                "speed": 250.0,
                "passes": 2
            }
        }


class PredictionRequest(BaseModel):
    """Request model for parameter prediction"""
    machineBrand: str = Field(..., min_length=1, max_length=100, description="Laser machine brand/model")
    laserPower: float = Field(..., gt=0, le=200, description="Machine laser power in Watts")
    materialType: str = Field(..., min_length=1, max_length=50, description="Material type")
    materialThickness: float = Field(..., gt=0, le=50, description="Material thickness in mm")
    processes: List[str] = Field(..., min_items=1, max_items=3, description="Process types")

    @validator('processes')
    def validate_processes(cls, v):
        """Validate process types"""
        valid_processes = {'cutting', 'engraving', 'scoring'}
        invalid = [p for p in v if p not in valid_processes]
        if invalid:
            raise ValueError(f"Invalid process types: {invalid}. Valid: {valid_processes}")
        if len(v) != len(set(v)):
            raise ValueError("Duplicate process types not allowed")
        return v

    @validator('materialType')
    def validate_material(cls, v):
        """Normalize material type"""
        v = v.strip()
        if len(v) < 2:
            raise ValueError("Material type must be at least 2 characters")
        return v

    @validator('machineBrand')
    def validate_brand(cls, v):
        """Normalize machine brand"""
        return v.strip()

    class Config:
        schema_extra = {
            "example": {
                "machineBrand": "Epilog Laser Fusion Pro",
                "laserPower": 100,
                "materialType": "Ahşap",
                "materialThickness": 5.0,
                "processes": ["cutting", "engraving"]
            }
        }


class PredictionResponse(BaseModel):
    """Response model for predictions"""
    predictions: Dict[str, ProcessParams]
    confidenceScore: float = Field(..., ge=0, le=1, description="Prediction confidence (0-1)")
    notes: str = Field(..., description="Additional notes or warnings")
    dataPointsUsed: int = Field(default=0, ge=0, description="Number of training data points used")

    class Config:
        schema_extra = {
            "example": {
                "predictions": {
                    "cutting": {
                        "power": 80.0,
                        "speed": 230.0,
                        "passes": 2
                    }
                },
                "confidenceScore": 0.75,
                "notes": "Prediction based on 150 similar experiments",
                "dataPointsUsed": 150
            }
        }


class HealthResponse(BaseModel):
    """Health check response"""
    status: str
    service: str
    version: str
    timestamp: str
    endpoints: Optional[List[str]] = None


class ErrorResponse(BaseModel):
    """Error response model"""
    error: str
    detail: Optional[str] = None
    timestamp: str


# ============= ERROR HANDLERS =============

@app.exception_handler(ValueError)
async def value_error_handler(request: Request, exc: ValueError):
    """Handle validation errors"""
    logger.warning(f"Validation error: {str(exc)}")
    return JSONResponse(
        status_code=400,
        content=ErrorResponse(
            error="Validation Error",
            detail=str(exc),
            timestamp=datetime.utcnow().isoformat()
        ).dict()
    )


@app.exception_handler(Exception)
async def general_error_handler(request: Request, exc: Exception):
    """Handle unexpected errors"""
    logger.exception(f"Unexpected error: {str(exc)}")
    return JSONResponse(
        status_code=500,
        content=ErrorResponse(
            error="Internal Server Error",
            detail="An unexpected error occurred. Please try again later.",
            timestamp=datetime.utcnow().isoformat()
        ).dict()
    )


# ============= UTILITY FUNCTIONS =============

def get_material_cutting_params(material: str) -> tuple:
    """Get base cutting parameters for material"""
    material = material.lower()
    
    material_params = {
        'ahşap': (65, 3.0),
        'ahsap': (65, 3.0),
        'wood': (65, 3.0),
        'mdf': (70, 3.5),
        'plexiglass': (55, 2.5),
        'akrilik': (55, 2.5),
        'acrylic': (55, 2.5),
        'karton': (35, 2.0),
        'cardboard': (35, 2.0),
        'deri': (40, 1.5),
        'leather': (40, 1.5),
    }
    
    return material_params.get(material, (70, 3.0))


def get_material_cutting_speeds(material: str) -> tuple:
    """Get base cutting speeds for material"""
    material = material.lower()
    
    speed_params = {
        'ahşap': (320, 18),
        'ahsap': (320, 18),
        'wood': (320, 18),
        'mdf': (300, 20),
        'plexiglass': (380, 25),
        'akrilik': (380, 25),
        'acrylic': (380, 25),
        'karton': (450, 15),
        'cardboard': (450, 15),
        'deri': (400, 12),
        'leather': (400, 12),
    }
    
    return speed_params.get(material, (300, 20))


def calculate_cutting_params(material: str, thickness: float) -> ProcessParams:
    """Calculate cutting parameters"""
    base_power, power_mult = get_material_cutting_params(material)
    base_speed, speed_mult = get_material_cutting_speeds(material)
    
    power = base_power + (thickness * power_mult)
    speed = base_speed - (thickness * speed_mult)
    passes = max(1, int(thickness / 4))
    
    # Apply limits
    power = round(max(10, min(100, power)), 1)
    speed = round(max(50, min(800, speed)), 0)
    passes = min(10, passes)
    
    return ProcessParams(power=power, speed=speed, passes=passes)


def calculate_engraving_params(material: str, thickness: float) -> ProcessParams:
    """Calculate engraving parameters"""
    base_power = 40 + (thickness * 2)
    base_speed = 500 - (thickness * 15)
    
    power = round(max(10, min(100, base_power)), 1)
    speed = round(max(100, min(800, base_speed)), 0)
    
    return ProcessParams(power=power, speed=speed, passes=1)


def calculate_scoring_params(material: str, thickness: float) -> ProcessParams:
    """Calculate scoring parameters"""
    base_power = 55 + (thickness * 2.5)
    base_speed = 400 - (thickness * 18)
    
    power = round(max(10, min(100, base_power)), 1)
    speed = round(max(80, min(700, base_speed)), 0)
    
    return ProcessParams(power=power, speed=speed, passes=1)


def get_confidence_score(data_points: int = 0) -> float:
    """Calculate confidence score based on available data"""
    if data_points == 0:
        return 0.50  # Base algorithm only
    elif data_points < 10:
        return 0.60
    elif data_points < 50:
        return 0.70
    elif data_points < 100:
        return 0.80
    else:
        return 0.90


def generate_notes(confidence: float, data_points: int) -> str:
    """Generate notes based on prediction quality"""
    if confidence >= 0.80:
        return f"✓ Yüksek güvenilirlik: {data_points} benzer deney verisine dayanıyor."
    elif confidence >= 0.65:
        return f"ℹ️ Orta güvenilirlik: {data_points} veri noktası kullanıldı. Daha fazla topluluk verisi ile iyileşecek."
    else:
        return "⚠️ Bu tahmin temel algoritmaya dayanıyor. Daha iyi sonuçlar için topluluk verisi eklenmeli."


# ============= API ENDPOINTS =============

@app.get("/", response_model=HealthResponse)
async def root():
    """Root endpoint - API information"""
    return HealthResponse(
        status="healthy",
        service="LaserTuner ML API",
        version="2.0.0",
        timestamp=datetime.utcnow().isoformat()
    )


@app.get("/health", response_model=HealthResponse)
async def health_check():
    """Health check endpoint"""
    return HealthResponse(
        status="healthy",
        service="LaserTuner ML API",
        version="2.0.0",
        timestamp=datetime.utcnow().isoformat(),
        endpoints=["/", "/health", "/predict", "/test"]
    )


@app.post("/predict", response_model=PredictionResponse)
async def predict(request: PredictionRequest):
    """
    Predict laser cutting parameters
    
    - **machineBrand**: Laser machine brand/model
    - **laserPower**: Machine power in Watts (1-200)
    - **materialType**: Material type (e.g., "Ahşap", "MDF", "Plexiglass")
    - **materialThickness**: Thickness in mm (0.1-50)
    - **processes**: List of process types ["cutting", "engraving", "scoring"]
    """
    start_time = datetime.now()
    
    try:
        logger.info(
            f"Prediction request: {request.materialType} "
            f"{request.materialThickness}mm, processes: {request.processes}"
        )
        
        predictions = {}
        material = request.materialType.lower()
        thickness = request.materialThickness
        
        # Calculate parameters for each process
        for process_type in request.processes:
            if process_type == 'cutting':
                params = calculate_cutting_params(material, thickness)
            elif process_type == 'engraving':
                params = calculate_engraving_params(material, thickness)
            elif process_type == 'scoring':
                params = calculate_scoring_params(material, thickness)
            else:
                raise ValueError(f"Unknown process type: {process_type}")
            
            predictions[process_type] = params
        
        # Calculate confidence and notes
        data_points = 0  # TODO: Get from database when ML model is ready
        confidence = get_confidence_score(data_points)
        notes = generate_notes(confidence, data_points)
        
        # Create response
        response = PredictionResponse(
            predictions=predictions,
            confidenceScore=confidence,
            notes=notes,
            dataPointsUsed=data_points
        )
        
        duration = (datetime.now() - start_time).total_seconds()
        logger.info(
            f"Prediction successful: {len(predictions)} processes, "
            f"duration: {duration:.3f}s"
        )
        
        return response
        
    except ValueError as e:
        logger.warning(f"Validation error in prediction: {str(e)}")
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        logger.exception(f"Unexpected error in prediction: {str(e)}")
        raise HTTPException(
            status_code=500,
            detail="Tahmin sırasında bir hata oluştu. Lütfen tekrar deneyin."
        )


@app.get("/test")
async def test_endpoint():
    """Test endpoint with example request"""
    return {
        "status": "ok",
        "message": "API is working!",
        "example_request": {
            "machineBrand": "Epilog Laser Fusion Pro",
            "laserPower": 100,
            "materialType": "Ahşap",
            "materialThickness": 5,
            "processes": ["cutting", "engraving"]
        },
        "example_curl": """
curl -X POST "https://your-api.onrender.com/predict" \\
  -H "Content-Type: application/json" \\
  -d '{
    "machineBrand": "Epilog Laser",
    "laserPower": 100,
    "materialType": "Ahşap",
    "materialThickness": 5,
    "processes": ["cutting"]
  }'
        """
    }


# ============= STARTUP/SHUTDOWN =============

@app.on_event("startup")
async def startup_event():
    """Run on application startup"""
    logger.info("="*50)
    logger.info("LaserTuner ML API Starting...")
    logger.info(f"Version: 2.0.0")
    logger.info(f"Allowed Origins: {ALLOWED_ORIGINS}")
    logger.info("="*50)


@app.on_event("shutdown")
async def shutdown_event():
    """Run on application shutdown"""
    logger.info("LaserTuner ML API Shutting down...")


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