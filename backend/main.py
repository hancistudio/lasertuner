from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import List, Dict
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(title="LaserTuner ML API", version="1.0.0")

# CORS - Netlify domain'inizi ekleyin
app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "https://lasertuner.netlify.app",
        "http://localhost:*",
        "*"  # Geliştirme için, production'da kaldırın
    ],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

class ProcessParams(BaseModel):
    power: float
    speed: float
    passes: int

class PredictionRequest(BaseModel):
    machineBrand: str
    laserPower: float
    materialType: str
    materialThickness: float
    processes: List[str]

class PredictionResponse(BaseModel):
    predictions: Dict[str, ProcessParams]
    confidenceScore: float
    notes: str
    dataPointsUsed: int

@app.get("/")
async def root():
    return {
        "status": "healthy",
        "service": "LaserTuner ML API",
        "version": "1.0.0",
        "message": "Welcome to LaserTuner ML API"
    }

@app.get("/health")
async def health_check():
    return {
        "status": "healthy",
        "service": "LaserTuner ML API",
        "endpoints": ["/", "/health", "/predict"]
    }

@app.post("/predict", response_model=PredictionResponse)
async def predict(request: PredictionRequest):
    """
    Laser kesim parametreleri tahmini
    """
    try:
        logger.info(f"Prediction request: {request.materialType}, {request.materialThickness}mm")
        
        predictions = {}
        
        for process_type in request.processes:
            thickness = request.materialThickness
            material = request.materialType.lower()
            
            # Materyal bazlı hesaplamalar
            if process_type == 'cutting':
                if 'ahşap' in material or 'ahsap' in material:
                    base_power = 65
                    power_mult = 3.0
                    base_speed = 320
                    speed_mult = 18
                elif 'mdf' in material:
                    base_power = 70
                    power_mult = 3.5
                    base_speed = 300
                    speed_mult = 20
                elif 'plexiglass' in material or 'akrilik' in material:
                    base_power = 55
                    power_mult = 2.5
                    base_speed = 380
                    speed_mult = 25
                else:  # Varsayılan
                    base_power = 70
                    power_mult = 3.0
                    base_speed = 300
                    speed_mult = 20
                
                power = base_power + (thickness * power_mult)
                speed = base_speed - (thickness * speed_mult)
                passes = max(1, int(thickness / 4))
                
            elif process_type == 'engraving':
                power = 40 + (thickness * 2)
                speed = 500 - (thickness * 15)
                passes = 1
                
            else:  # scoring
                power = 55 + (thickness * 2.5)
                speed = 400 - (thickness * 18)
                passes = 1
            
            # Limitleri uygula
            power = round(max(10, min(100, power)), 1)
            speed = round(max(50, speed), 0)
            
            predictions[process_type] = ProcessParams(
                power=power,
                speed=speed,
                passes=passes
            )
        
        # Güven skoru hesapla
        confidence = 0.65
        notes = "⚠️ Bu tahmin basit bir algoritmaya dayanıyor. Daha fazla topluluk verisi eklendiğinde tahminler iyileşecek."
        
        logger.info(f"Prediction successful: {len(predictions)} processes")
        
        return PredictionResponse(
            predictions=predictions,
            confidenceScore=confidence,
            notes=notes,
            dataPointsUsed=0
        )
        
    except Exception as e:
        logger.error(f"Prediction error: {e}")
        raise HTTPException(status_code=500, detail=f"Tahmin hatası: {str(e)}")

@app.get("/test")
async def test_endpoint():
    """Test endpoint"""
    return {
        "status": "ok",
        "message": "API is working!",
        "example_request": {
            "machineBrand": "Epilog Laser",
            "laserPower": 100,
            "materialType": "Ahşap",
            "materialThickness": 5,
            "processes": ["cutting", "engraving"]
        }
    }

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
