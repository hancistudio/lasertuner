# -*- coding: utf-8 -*-
"""
ML Prediction Service
Combines static algorithms with real user data
"""

import logging
from typing import Dict, List, Tuple
from statistics import mean, median

logger = logging.getLogger(__name__)

class MLPredictionService:
    """Service for making predictions using real data"""
    
    def __init__(self):
        """Initialize prediction service"""
        self.min_data_points = 3  # Minimum data points to use real data
        self.quality_threshold = 5  # Minimum quality score
    
    def predict_from_data(
        self,
        experiments: List[Dict],
        process_type: str,
        material_type: str,
        thickness: float
    ) -> Tuple[Dict, float, str]:
        """
        Make prediction based on real experiment data
        
        Args:
            experiments: List of similar experiments
            process_type: 'cutting', 'engraving', or 'scoring'
            material_type: Material type
            thickness: Material thickness
        
        Returns:
            Tuple of (predictions, confidence_score, notes)
        """
        # Filter experiments that have this process type
        relevant_experiments = []
        for exp in experiments:
            processes = exp.get('processes', {})
            if process_type in processes:
                # Check quality score
                quality = exp.get('qualityScores', {}).get(process_type, 0)
                if quality >= self.quality_threshold:
                    relevant_experiments.append(exp)
        
        data_points = len(relevant_experiments)
        
        # If not enough data, return None (will use static algorithm)
        if data_points < self.min_data_points:
            return None, 0.0, f"Yetersiz veri ({data_points} deney)"
        
        # Calculate predictions from real data
        predictions = self._calculate_average_params(
            relevant_experiments,
            process_type
        )
        
        # Calculate confidence score
        confidence = self._calculate_confidence(
            data_points,
            relevant_experiments,
            process_type
        )
        
        # Generate notes
        notes = self._generate_notes(
            data_points,
            confidence,
            relevant_experiments,
            process_type
        )
        
        logger.info(
            f"✅ Prediction from {data_points} experiments: "
            f"power={predictions['power']}, speed={predictions['speed']}, "
            f"confidence={confidence:.2f}"
        )
        
        return predictions, confidence, notes
    
    def _calculate_average_params(
        self,
        experiments: List[Dict],
        process_type: str
    ) -> Dict:
        """Calculate weighted average parameters"""
        powers = []
        speeds = []
        passes_list = []
        weights = []
        
        for exp in experiments:
            process_data = exp['processes'][process_type]
            quality = exp.get('qualityScores', {}).get(process_type, 5)
            approve_count = exp.get('approveCount', 0)
            
            # Weight: quality score + approval votes
            weight = quality + (approve_count * 0.5)
            
            powers.append(process_data['power'])
            speeds.append(process_data['speed'])
            passes_list.append(process_data['passes'])
            weights.append(weight)
        
        # Weighted average
        total_weight = sum(weights)
        
        avg_power = sum(p * w for p, w in zip(powers, weights)) / total_weight
        avg_speed = sum(s * w for s, w in zip(speeds, weights)) / total_weight
        avg_passes = round(sum(p * w for p, w in zip(passes_list, weights)) / total_weight)
        
        # Also calculate median for robustness
        median_power = median(powers)
        median_speed = median(speeds)
        
        # Use average but constrain by median (avoid outliers)
        final_power = (avg_power * 0.7) + (median_power * 0.3)
        final_speed = (avg_speed * 0.7) + (median_speed * 0.3)
        
        return {
            'power': round(max(10, min(100, final_power)), 1),
            'speed': round(max(50, min(1000, final_speed)), 0),
            'passes': max(1, min(10, avg_passes))
        }
    
    def _calculate_confidence(
        self,
        data_points: int,
        experiments: List[Dict],
        process_type: str
    ) -> float:
        """Calculate confidence score based on data quality and quantity"""
        # Base confidence from data points
        if data_points >= 50:
            base_confidence = 0.90
        elif data_points >= 20:
            base_confidence = 0.80
        elif data_points >= 10:
            base_confidence = 0.70
        elif data_points >= 5:
            base_confidence = 0.65
        else:
            base_confidence = 0.60
        
        # Adjust based on data quality
        qualities = [
            exp.get('qualityScores', {}).get(process_type, 5)
            for exp in experiments
        ]
        avg_quality = mean(qualities)
        quality_factor = avg_quality / 10  # 0.0 to 1.0
        
        # Adjust based on consistency (variance)
        powers = [exp['processes'][process_type]['power'] for exp in experiments]
        speeds = [exp['processes'][process_type]['speed'] for exp in experiments]
        
        power_variance = self._calculate_variance(powers)
        speed_variance = self._calculate_variance(speeds)
        
        # Lower variance = higher confidence
        consistency_factor = 1.0 - min(0.2, (power_variance + speed_variance) / 2)
        
        # Final confidence
        confidence = base_confidence * quality_factor * consistency_factor
        
        return round(min(0.95, max(0.55, confidence)), 2)
    
    def _calculate_variance(self, values: List[float]) -> float:
        """Calculate normalized variance (0.0 to 1.0)"""
        if len(values) < 2:
            return 0.0
        
        avg = mean(values)
        variance = sum((x - avg) ** 2 for x in values) / len(values)
        normalized = variance / (avg ** 2) if avg > 0 else 1.0
        
        return min(1.0, normalized)
    
    def _generate_notes(
        self,
        data_points: int,
        confidence: float,
        experiments: List[Dict],
        process_type: str
    ) -> str:
        """Generate informative notes about the prediction"""
        qualities = [
            exp.get('qualityScores', {}).get(process_type, 5)
            for exp in experiments
        ]
        avg_quality = mean(qualities)
        
        # Gold standard count
        gold_count = sum(
            1 for exp in experiments
            if exp.get('dataSource') in ['researcher', 'researcher_import']
        )
        
        notes_parts = []
        
        # Main note
        if confidence >= 0.80:
            notes_parts.append(f"✅ Yüksek güvenilirlik")
        elif confidence >= 0.65:
            notes_parts.append(f"ℹ️ Orta güvenilirlik")
        else:
            notes_parts.append(f"⚠️ Düşük güvenilirlik")
        
        # Data info
        notes_parts.append(
            f"{data_points} benzer deney verisine dayanıyor"
        )
        
        # Quality info
        notes_parts.append(
            f"Ortalama kalite: {avg_quality:.1f}/10"
        )
        
        # Gold standard info
        if gold_count > 0:
            notes_parts.append(
                f"🌟 {gold_count} gold standard veri dahil"
            )
        
        return " | ".join(notes_parts)
    
    def get_fallback_prediction(
        self,
        material_type: str,
        thickness: float,
        process_type: str
    ) -> Dict:
        """Get fallback prediction using static algorithm"""
        # Import here to avoid circular dependency
        from main import (
            calculate_cutting_params,
            calculate_engraving_params,
            calculate_scoring_params
        )
        
        if process_type == 'cutting':
            params = calculate_cutting_params(material_type, thickness)
        elif process_type == 'engraving':
            params = calculate_engraving_params(material_type, thickness)
        elif process_type == 'scoring':
            params = calculate_scoring_params(material_type, thickness)
        else:
            # Default params
            return {'power': 50.0, 'speed': 300.0, 'passes': 1}
        
        return {
            'power': params.power,
            'speed': params.speed,
            'passes': params.passes
        }


# Global instance
_ml_service = None

def get_ml_service() -> MLPredictionService:
    """Get or create ML service singleton"""
    global _ml_service
    if _ml_service is None:
        _ml_service = MLPredictionService()
    return _ml_service