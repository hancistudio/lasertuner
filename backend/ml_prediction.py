# -*- coding: utf-8 -*-
"""
ML Prediction Service - IMPROVED VERSION
Combines static algorithms with real user data + smart scaling
"""

import logging
from typing import Dict, List, Tuple, Optional
from statistics import mean, median

logger = logging.getLogger(__name__)

# Makina aileleri - benzer makinaları grupla
MACHINE_FAMILIES = {
    'diode': ['xtool', 'atomstack', 'ortur', 'sculpfun', 'creality'],
    'co2': ['epilog', 'trotec', 'thunder', 'universal', 'boss'],
    'fiber': ['raycus', 'jpt', 'max photonics', 'ipg'],
}

class MLPredictionService:
    """Service for making predictions using real data with smart scaling"""
    
    def __init__(self):
        """Initialize prediction service"""
        self.min_data_points = 3  # Minimum data points to use real data
        self.quality_threshold = 5  # Minimum quality score
        self.power_tolerance = 20  # ±20W tolerance for power matching
        self.thickness_tolerance = 2.0  # ±2mm tolerance
    
    def get_machine_family(self, machine_brand: str) -> str:
        """Determine machine family from brand name"""
        brand_lower = machine_brand.lower()
        
        for family, brands in MACHINE_FAMILIES.items():
            if any(brand in brand_lower for brand in brands):
                return family
        
        return 'unknown'
    
    def predict_from_data(
        self,
        experiments: List[Dict],
        process_type: str,
        material_type: str,
        thickness: float,
        target_power: float = None
    ) -> Tuple[Optional[Dict], float, str]:
        """
        Make prediction based on real experiment data with smart scaling
        
        Args:
            experiments: List of similar experiments
            process_type: 'cutting', 'engraving', or 'scoring'
            material_type: Material type
            thickness: Material thickness
            target_power: Target laser power (for scaling)
        
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
        
        # Calculate base predictions from real data
        base_predictions = self._calculate_average_params(
            relevant_experiments,
            process_type
        )
        
        # Check if power scaling is needed
        avg_source_power = mean([e.get('laserPower', 0) for e in relevant_experiments])
        power_difference = abs(avg_source_power - target_power) if target_power else 0
        
        if target_power and power_difference > self.power_tolerance:
            # Apply power scaling
            scaled_predictions = self._scale_by_power(
                base_predictions,
                source_power=avg_source_power,
                target_power=target_power
            )
            predictions = scaled_predictions
            was_scaled = True
        else:
            predictions = base_predictions
            was_scaled = False
        
        # Calculate confidence score
        confidence = self._calculate_confidence(
            data_points,
            relevant_experiments,
            process_type,
            was_scaled=was_scaled,
            power_difference=power_difference
        )
        
        # Generate notes
        notes = self._generate_notes(
            data_points,
            confidence,
            relevant_experiments,
            process_type,
            was_scaled=was_scaled,
            avg_source_power=avg_source_power,
            target_power=target_power
        )
        
        logger.info(
            f"✅ Prediction from {data_points} experiments: "
            f"power={predictions['power']}, speed={predictions['speed']}, "
            f"confidence={confidence:.2f}, scaled={was_scaled}"
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
            
            # Weight: quality score + approval votes + gold standard bonus
            weight = quality + (approve_count * 0.5)
            
            # Bonus for gold standard data
            if exp.get('dataSource') in ['researcher', 'researcher_import']:
                weight *= 1.5
            
            powers.append(process_data['power'])
            speeds.append(process_data['speed'])
            passes_list.append(process_data['passes'])
            weights.append(weight)
        
        # Weighted average
        total_weight = sum(weights)
        
        avg_power = sum(p * w for p, w in zip(powers, weights)) / total_weight
        avg_speed = sum(s * w for s, w in zip(speeds, weights)) / total_weight
        avg_passes = round(sum(p * w for p, w in zip(passes_list, weights)) / total_weight)
        
        # Also calculate median for robustness (avoid outliers)
        median_power = median(powers)
        median_speed = median(speeds)
        
        # Use weighted average but constrain by median
        final_power = (avg_power * 0.7) + (median_power * 0.3)
        final_speed = (avg_speed * 0.7) + (median_speed * 0.3)
        
        return {
            'power': round(max(10, min(100, final_power)), 1),
            'speed': round(max(50, min(1000, final_speed)), 0),
            'passes': max(1, min(10, avg_passes))
        }
    
    def _scale_by_power(
        self,
        params: Dict,
        source_power: float,
        target_power: float
    ) -> Dict:
        """
        Scale parameters based on laser power difference
        
        Logic:
        - Higher power → can cut faster (speed increases)
        - Higher power → use lower power percentage
        - Passes usually stay the same
        """
        if source_power <= 0 or target_power <= 0:
            return params
        
        power_ratio = target_power / source_power
        
        # Power scaling: inverse relationship (higher laser = lower %)
        scaled_power = params['power'] / (power_ratio ** 0.5)
        
        # Speed scaling: direct relationship (higher laser = faster)
        scaled_speed = params['speed'] * (power_ratio ** 0.4)
        
        # Passes: only increase if power is much lower
        if power_ratio < 0.5:
            scaled_passes = params['passes'] + 1
        else:
            scaled_passes = params['passes']
        
        return {
            'power': round(max(10, min(100, scaled_power)), 1),
            'speed': round(max(50, min(1000, scaled_speed)), 0),
            'passes': max(1, min(10, scaled_passes))
        }
    
    def _calculate_confidence(
        self,
        data_points: int,
        experiments: List[Dict],
        process_type: str,
        was_scaled: bool = False,
        power_difference: float = 0
    ) -> float:
        """Calculate confidence score based on data quality and quantity"""
        # Base confidence from data points
        if data_points >= 50:
            base_confidence = 0.90
        elif data_points >= 20:
            base_confidence = 0.85
        elif data_points >= 10:
            base_confidence = 0.75
        elif data_points >= 5:
            base_confidence = 0.68
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
        
        # ✨ NEW: Laser power diversity check
        laser_powers = [exp.get('laserPower', 0) for exp in experiments]
        power_range = max(laser_powers) - min(laser_powers)
        
        if power_range < 20:
            power_diversity_factor = 1.0  # Narrow range - good
        elif power_range < 50:
            power_diversity_factor = 0.90  # Medium range
        else:
            power_diversity_factor = 0.75  # Wide range - mixed data
        
        # ✨ NEW: Machine brand diversity check
        brands = [exp.get('machineBrand', '').lower() for exp in experiments]
        unique_brands = len(set(brands))
        
        if unique_brands == 1:
            brand_factor = 1.0  # Single brand - consistent
        elif unique_brands <= 3:
            brand_factor = 0.90  # Few brands - good
        else:
            brand_factor = 0.80  # Many brands - general data
        
        # ✨ NEW: Scaling penalty
        if was_scaled:
            if power_difference < 30:
                scaling_factor = 0.90  # Small difference
            elif power_difference < 60:
                scaling_factor = 0.80  # Medium difference
            else:
                scaling_factor = 0.70  # Large difference
        else:
            scaling_factor = 1.0
        
        # ✨ NEW: Gold standard bonus
        gold_count = sum(
            1 for exp in experiments
            if exp.get('dataSource') in ['researcher', 'researcher_import']
        )
        gold_ratio = gold_count / len(experiments)
        gold_bonus = 1.0 + (gold_ratio * 0.1)  # Up to +10%
        
        # Final confidence
        confidence = (
            base_confidence * 
            quality_factor * 
            consistency_factor * 
            power_diversity_factor *
            brand_factor *
            scaling_factor *
            gold_bonus
        )
        
        return round(min(0.95, max(0.55, confidence)), 2)
    
    def _calculate_variance(self, values: List[float]) -> float:
        """Calculate normalized variance (0.0 to 1.0)"""
        if len(values) < 2:
            return 0.0
        
        avg = mean(values)
        if avg == 0:
            return 1.0
        
        variance = sum((x - avg) ** 2 for x in values) / len(values)
        normalized = variance / (avg ** 2)
        
        return min(1.0, normalized)
    
    def _generate_notes(
        self,
        data_points: int,
        confidence: float,
        experiments: List[Dict],
        process_type: str,
        was_scaled: bool = False,
        avg_source_power: float = 0,
        target_power: float = None
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
        
        # Machine diversity
        brands = set([exp.get('machineBrand', 'Unknown') for exp in experiments])
        
        notes_parts = []
        
        # Main confidence indicator
        if confidence >= 0.80:
            notes_parts.append("✅ Yüksek güvenilirlik")
        elif confidence >= 0.65:
            notes_parts.append("ℹ️ Orta güvenilirlik")
        else:
            notes_parts.append("⚠️ Düşük güvenilirlik")
        
        # Data info
        notes_parts.append(f"{data_points} benzer deney verisine dayanıyor")
        
        # Scaling info
        if was_scaled and target_power and avg_source_power:
            notes_parts.append(
                f"🔧 {avg_source_power:.0f}W → {target_power:.0f}W güç ölçeklendi"
            )
        
        # Quality info
        notes_parts.append(f"Ortalama kalite: {avg_quality:.1f}/10")
        
        # Gold standard info
        if gold_count > 0:
            notes_parts.append(f"🌟 {gold_count} gold standard veri")
        
        # Machine diversity warning
        if len(brands) > 3:
            notes_parts.append(f"⚙️ {len(brands)} farklı makina")
        
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