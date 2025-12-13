# -*- coding: utf-8 -*-
"""
Feature Engineering for Diode Laser Transfer Learning
Converts Firebase data to numerical features for deep learning model
"""

import numpy as np
import logging

logger = logging.getLogger(__name__)

class MaterialFeatureEncoder:
    """
    Malzeme Ã¶zelliklerini numerical vector'e Ã§evir
    Firebase'den gelen data â†’ Model input features
    
    Tezde bahsedilen: "malzeme tÃ¼rÃ¼, kalÄ±nlÄ±k, yoÄŸunluk, termal Ã¶zellikler"
    """
    
    # Malzeme fiziksel Ã¶zellikleri (normalized)
    MATERIAL_PROPERTIES = {
        # ===== AHÅžAP ÃœRÃœNLERÄ° =====
        'ahÅŸap': {
            'density': 0.60,           # g/cmÂ³
            'thermal': 0.15,           # W/mK (thermal conductivity)
            'melt': 0.0,               # Melting point (0 for organic)
            'absorb': 0.85,            # 445nm absorptivity
        },
        'ahsap': {
            'density': 0.60,
            'thermal': 0.15,
            'melt': 0.0,
            'absorb': 0.85,
        },
        'wood': {
            'density': 0.60,
            'thermal': 0.15,
            'melt': 0.0,
            'absorb': 0.85,
        },
        'kontrplak': {
            'density': 0.65,
            'thermal': 0.14,
            'melt': 0.0,
            'absorb': 0.83,
        },
        'plywood': {
            'density': 0.65,
            'thermal': 0.14,
            'melt': 0.0,
            'absorb': 0.83,
        },
        'mdf': {
            'density': 0.75,
            'thermal': 0.12,
            'melt': 0.0,
            'absorb': 0.80,
        },
        'balsa': {
            'density': 0.15,
            'thermal': 0.05,
            'melt': 0.0,
            'absorb': 0.88,
        },
        'bambu': {
            'density': 0.70,
            'thermal': 0.16,
            'melt': 0.0,
            'absorb': 0.82,
        },
        'bamboo': {
            'density': 0.70,
            'thermal': 0.16,
            'melt': 0.0,
            'absorb': 0.82,
        },
        'kayÄ±n': {
            'density': 0.72,
            'thermal': 0.17,
            'melt': 0.0,
            'absorb': 0.81,
        },
        'kayin': {
            'density': 0.72,
            'thermal': 0.17,
            'melt': 0.0,
            'absorb': 0.81,
        },
        'beech': {
            'density': 0.72,
            'thermal': 0.17,
            'melt': 0.0,
            'absorb': 0.81,
        },
        'meÅŸe': {
            'density': 0.80,
            'thermal': 0.18,
            'melt': 0.0,
            'absorb': 0.79,
        },
        'mese': {
            'density': 0.80,
            'thermal': 0.18,
            'melt': 0.0,
            'absorb': 0.79,
        },
        'oak': {
            'density': 0.80,
            'thermal': 0.18,
            'melt': 0.0,
            'absorb': 0.79,
        },
        'ceviz': {
            'density': 0.65,
            'thermal': 0.16,
            'melt': 0.0,
            'absorb': 0.83,
        },
        'walnut': {
            'density': 0.65,
            'thermal': 0.16,
            'melt': 0.0,
            'absorb': 0.83,
        },
        'akÃ§aaÄŸaÃ§': {
            'density': 0.70,
            'thermal': 0.17,
            'melt': 0.0,
            'absorb': 0.81,
        },
        'akcaagac': {
            'density': 0.70,
            'thermal': 0.17,
            'melt': 0.0,
            'absorb': 0.81,
        },
        'maple': {
            'density': 0.70,
            'thermal': 0.17,
            'melt': 0.0,
            'absorb': 0.81,
        },
        'huÅŸ': {
            'density': 0.65,
            'thermal': 0.15,
            'melt': 0.0,
            'absorb': 0.84,
        },
        'hus': {
            'density': 0.65,
            'thermal': 0.15,
            'melt': 0.0,
            'absorb': 0.84,
        },
        'birch': {
            'density': 0.65,
            'thermal': 0.15,
            'melt': 0.0,
            'absorb': 0.84,
        },
        'Ã§am': {
            'density': 0.50,
            'thermal': 0.12,
            'melt': 0.0,
            'absorb': 0.86,
        },
        'cam': {
            'density': 0.50,
            'thermal': 0.12,
            'melt': 0.0,
            'absorb': 0.86,
        },
        'pine': {
            'density': 0.50,
            'thermal': 0.12,
            'melt': 0.0,
            'absorb': 0.86,
        },
        'ladin': {
            'density': 0.45,
            'thermal': 0.11,
            'melt': 0.0,
            'absorb': 0.87,
        },
        'spruce': {
            'density': 0.45,
            'thermal': 0.11,
            'melt': 0.0,
            'absorb': 0.87,
        },
        'fir': {
            'density': 0.45,
            'thermal': 0.11,
            'melt': 0.0,
            'absorb': 0.87,
        },
        
        # ===== ORGANÄ°K MALZEMELER =====
        'deri': {
            'density': 0.85,
            'thermal': 0.16,
            'melt': 0.0,
            'absorb': 0.75,
        },
        'leather': {
            'density': 0.85,
            'thermal': 0.16,
            'melt': 0.0,
            'absorb': 0.75,
        },
        'karton': {
            'density': 0.45,
            'thermal': 0.08,
            'melt': 0.0,
            'absorb': 0.90,
        },
        'cardboard': {
            'density': 0.45,
            'thermal': 0.08,
            'melt': 0.0,
            'absorb': 0.90,
        },
        'kaÄŸÄ±t': {
            'density': 0.30,
            'thermal': 0.05,
            'melt': 0.0,
            'absorb': 0.92,
        },
        'kagit': {
            'density': 0.30,
            'thermal': 0.05,
            'melt': 0.0,
            'absorb': 0.92,
        },
        'paper': {
            'density': 0.30,
            'thermal': 0.05,
            'melt': 0.0,
            'absorb': 0.92,
        },
        'kumaÅŸ': {
            'density': 0.40,
            'thermal': 0.06,
            'melt': 0.0,
            'absorb': 0.88,
        },
        'kumas': {
            'density': 0.40,
            'thermal': 0.06,
            'melt': 0.0,
            'absorb': 0.88,
        },
        'fabric': {
            'density': 0.40,
            'thermal': 0.06,
            'melt': 0.0,
            'absorb': 0.88,
        },
        'keÃ§e': {
            'density': 0.35,
            'thermal': 0.05,
            'melt': 0.0,
            'absorb': 0.89,
        },
        'kece': {
            'density': 0.35,
            'thermal': 0.05,
            'melt': 0.0,
            'absorb': 0.89,
        },
        'felt': {
            'density': 0.35,
            'thermal': 0.05,
            'melt': 0.0,
            'absorb': 0.89,
        },
        'mantar': {
            'density': 0.25,
            'thermal': 0.04,
            'melt': 0.0,
            'absorb': 0.91,
        },
        'cork': {
            'density': 0.25,
            'thermal': 0.04,
            'melt': 0.0,
            'absorb': 0.91,
        },
        
        # ===== SENTETÄ°K MALZEMELER =====
        'akrilik': {
            'density': 1.18,
            'thermal': 0.19,
            'melt': 0.42,  # ~160Â°C normalized
            'absorb': 0.65,
        },
        'acrylic': {
            'density': 1.18,
            'thermal': 0.19,
            'melt': 0.42,
            'absorb': 0.65,
        },
        'plexiglass': {
            'density': 1.18,
            'thermal': 0.19,
            'melt': 0.42,
            'absorb': 0.65,
        },
        'pleksiglas': {
            'density': 1.18,
            'thermal': 0.19,
            'melt': 0.42,
            'absorb': 0.65,
        },
        'pmma': {
            'density': 1.18,
            'thermal': 0.19,
            'melt': 0.42,
            'absorb': 0.65,
        },
        'lastik': {
            'density': 1.10,
            'thermal': 0.25,
            'melt': 0.35,
            'absorb': 0.70,
        },
        'rubber': {
            'density': 1.10,
            'thermal': 0.25,
            'melt': 0.35,
            'absorb': 0.70,
        },
        'kÃ¶pÃ¼k': {
            'density': 0.20,
            'thermal': 0.03,
            'melt': 0.30,
            'absorb': 0.93,
        },
        'kopuk': {
            'density': 0.20,
            'thermal': 0.03,
            'melt': 0.30,
            'absorb': 0.93,
        },
        'foam': {
            'density': 0.20,
            'thermal': 0.03,
            'melt': 0.30,
            'absorb': 0.93,
        },
        
        # ===== METAL (SINIRLI) =====
        'anodize_aluminyum': {
            'density': 2.70,
            'thermal': 2.05,
            'melt': 0.80,  # ~660Â°C normalized
            'absorb': 0.20,
        },
        'anodized_aluminum': {
            'density': 2.70,
            'thermal': 2.05,
            'melt': 0.80,
            'absorb': 0.20,
        },
        
        # ===== DÄ°ÄžER =====
        'diger': {
            'density': 0.70,
            'thermal': 0.15,
            'melt': 0.0,
            'absorb': 0.80,
        },
        'other': {
            'density': 0.70,
            'thermal': 0.15,
            'melt': 0.0,
            'absorb': 0.80,
        },
    }
    
    def encode(self, material_type: str, thickness: float, laser_power: float, 
               process_type: str) -> np.ndarray:
        """
        Firebase data â†’ Numerical features for model
        
        Args:
            material_type: Firebase'den gelen malzeme adÄ± (e.g., "AhÅŸap")
            thickness: KalÄ±nlÄ±k (mm)
            laser_power: Lazer gÃ¼cÃ¼ (W)
            process_type: 'cutting', 'engraving', 'scoring'
        
        Returns:
            numpy array shape (9,) = 
            [density_norm, thermal_norm, melt_norm, absorb, 
             thickness_norm, power_norm, 
             is_cutting, is_engraving, is_scoring]
        """
        # Malzeme Ã¶zelliklerini al (normalize edilmiÅŸ)
        material_lower = material_type.lower().strip()
        
        # Try exact match first
        props = self.MATERIAL_PROPERTIES.get(material_lower)
        
        # If not found, try partial match
        if props is None:
            for key in self.MATERIAL_PROPERTIES.keys():
                if key in material_lower or material_lower in key:
                    props = self.MATERIAL_PROPERTIES[key]
                    logger.info(f"âœ… Material matched: '{material_type}' â†’ '{key}'")
                    break
        
        # Default fallback
        if props is None:
            logger.warning(f"âš ï¸ Unknown material: {material_type}, using default")
            props = {
                'density': 0.70,
                'thermal': 0.15,
                'melt': 0.0,
                'absorb': 0.80,
            }
        
        # Feature vector oluÅŸtur (9 features)
        features = np.array([
            props['density'] / 3.0,           # Normalize (max ~3.0 g/cmÂ³)
            props['thermal'] / 2.5,           # Normalize (max ~2.5 W/mK)
            props['melt'],                    # Already 0-1
            props['absorb'],                  # Already 0-1
            thickness / 10.0,                 # Normalize (max 10mm)
            laser_power / 40.0,               # Normalize (max 40W)
            1.0 if process_type == 'cutting' else 0.0,
            1.0 if process_type == 'engraving' else 0.0,
            1.0 if process_type == 'scoring' else 0.0,
        ], dtype=np.float32)
        
        return features
    
    def encode_batch(self, firebase_data: list) -> tuple:
        """
        Birden fazla Firebase kaydÄ±nÄ± batch olarak encode et
        
        Args:
            firebase_data: List of dicts from get_training_data_for_transfer_learning()
            Each dict contains:
            {
                'materialType': str,
                'materialThickness': float,
                'laserPower': float,
                'processType': str,
                'targetPower': float,
                'targetSpeed': float,
                'targetPasses': int,
                'quality': int,
                'dataSource': str
            }
        
        Returns:
            (X, y_power, y_speed, y_passes)
            X shape: (N, 9)
            y_power shape: (N, 1)
            y_speed shape: (N, 1)
            y_passes shape: (N, 1)
        """
        X = []
        y_power = []
        y_speed = []
        y_passes = []
        
        for data in firebase_data:
            try:
                # Features encode et
                features = self.encode(
                    material_type=data['materialType'],
                    thickness=data['materialThickness'],
                    laser_power=data['laserPower'],
                    process_type=data['processType']
                )
                X.append(features)
                
                # Targets (normalize to 0-1 for better training)
                y_power.append(data['targetPower'] / 100.0)  # Power is 0-100%
                y_speed.append(data['targetSpeed'] / 500.0)  # Speed max 500 mm/s
                y_passes.append(data['targetPasses'] / 20.0)  # Passes max 20
                
            except Exception as e:
                logger.warning(f"âš ï¸ Failed to encode sample: {e}")
                continue
        
        if len(X) == 0:
            raise ValueError("No valid samples to encode")
        
        return (
            np.array(X, dtype=np.float32),
            np.array(y_power, dtype=np.float32).reshape(-1, 1),
            np.array(y_speed, dtype=np.float32).reshape(-1, 1),
            np.array(y_passes, dtype=np.float32).reshape(-1, 1)
        )
    
    def decode_predictions(self, power_norm: float, speed_norm: float, 
                          passes_norm: float) -> dict:
        """
        De-normalize model predictions to actual values
        
        Args:
            power_norm: Normalized power (0-1)
            speed_norm: Normalized speed (0-1)
            passes_norm: Normalized passes (0-1)
        
        Returns:
            {'power': float, 'speed': float, 'passes': int}
        """
        return {
            'power': np.clip(power_norm * 100.0, 10, 100),
            'speed': np.clip(speed_norm * 500.0, 50, 500),
            'passes': int(np.clip(round(passes_norm * 20.0), 1, 20))
        }


# Singleton instance
_feature_encoder = None

def get_feature_encoder() -> MaterialFeatureEncoder:
    """Get or create feature encoder singleton"""
    global _feature_encoder
    if _feature_encoder is None:
        _feature_encoder = MaterialFeatureEncoder()
    return _feature_encoder