# -*- coding: utf-8 -*-
"""
ML Prediction Service - FIREBASE DATA DRIVEN
Sadece Firebase'deki kullanıcı verilerini kullanır
Transfer Learning: Implicit similarity-based approach
"""

import logging
from typing import Dict, List, Tuple, Optional
from statistics import mean, median
import numpy as np

logger = logging.getLogger(__name__)

class MLPredictionService:
    """
    Firebase tabanlı tahmin servisi.
    
    Transfer Learning Yaklaşımı:
    1. Material similarity (benzer malzemeler)
    2. Thickness proximity (yakın kalınlıklar)
    3. Power adaptation (güç ölçekleme)
    4. Quality weighting (kaliteli veri öncelik)
    
    Bu implicit transfer learning yaklaşımıdır.
    """
    
    def __init__(self):
        self.min_data_points = 3
        self.quality_threshold = 5
        self.power_tolerance = 10  # ±10W (küçültüldü, daha hassas)
        self.thickness_tolerance = 1.5
    
    def predict_from_data(
        self,
        experiments: List[Dict],
        process_type: str,
        material_type: str,
        thickness: float,
        target_power: float
    ) -> Tuple[Optional[Dict], float, str]:
        """
        Firebase verilerinden tahmin yap.
        
        Args:
            experiments: Firebase'den gelen benzer deneyler
            process_type: 'cutting', 'engraving', 'scoring'
            material_type: Malzeme türü
            thickness: Kalınlık (mm)
            target_power: Hedef lazer gücü (W)
        
        Returns:
            (predictions_dict, confidence_score, notes_string)
        """
        # 1. Process type filtreleme
        relevant_experiments = self._filter_by_process_and_quality(
            experiments, process_type
        )
        
        data_points = len(relevant_experiments)
        
        # Yetersiz veri → None (static algorithm kullanılacak)
        if data_points < self.min_data_points:
            logger.info(f"⚠️ Insufficient data: {data_points} experiments")
            return None, 0.0, f"Yetersiz topluluk verisi ({data_points} deney)"
        
        # 2. Similarity scoring (TRANSFER LEARNING: similarity-based transfer)
        similarity_scores = self._calculate_similarity_scores(
            relevant_experiments,
            target_material=material_type,
            target_thickness=thickness,
            target_power=target_power
        )
        
        # 3. Weighted averaging (DOMAIN ADAPTATION)
        base_predictions = self._weighted_average(
            relevant_experiments,
            similarity_scores,
            process_type
        )
        
        # 4. Power scaling (FEW-SHOT LEARNING)
        avg_source_power = np.average(
            [e.get('laserPower', 20) for e in relevant_experiments],
            weights=similarity_scores
        )
        power_difference = abs(avg_source_power - target_power)
        
        if power_difference > self.power_tolerance:
            predictions = self._scale_by_power(
                base_predictions,
                source_power=avg_source_power,
                target_power=target_power
            )
            was_scaled = True
        else:
            predictions = base_predictions
            was_scaled = False
        
        # 5. Confidence calculation
        confidence = self._calculate_confidence(
            data_points=data_points,
            experiments=relevant_experiments,
            similarity_scores=similarity_scores,
            power_difference=power_difference,
            was_scaled=was_scaled
        )
        
        # 6. Notes generation
        notes = self._generate_notes(
            data_points=data_points,
            confidence=confidence,
            experiments=relevant_experiments,
            process_type=process_type,
            was_scaled=was_scaled,
            power_diff=power_difference
        )
        
        logger.info(
            f"✅ Prediction: {predictions['power']:.1f}%, {predictions['speed']:.0f}mm/s, "
            f"{predictions['passes']} passes | confidence={confidence:.2f}"
        )
        
        return predictions, confidence, notes
    
    def _filter_by_process_and_quality(
        self,
        experiments: List[Dict],
        process_type: str
    ) -> List[Dict]:
        """Process type ve quality threshold ile filtrele."""
        filtered = []
        for exp in experiments:
            processes = exp.get('processes', {})
            if process_type in processes:
                quality = exp.get('qualityScores', {}).get(process_type, 0)
                if quality >= self.quality_threshold:
                    filtered.append(exp)
        return filtered
    
    def _calculate_similarity_scores(
        self,
        experiments: List[Dict],
        target_material: str,
        target_thickness: float,
        target_power: float
    ) -> np.ndarray:
        """
        TRANSFER LEARNING CORE: Similarity-based knowledge transfer.
        
        Her deneyin hedef parametrelere benzerlik skoru.
        Bu skorlar, hangi deneylerden ne kadar bilgi transfer edileceğini belirler.
        """
        scores = []
        
        for exp in experiments:
            # 1. Material similarity (exact match veya similar group)
            exp_material = exp.get('materialType', '').lower()
            target_lower = target_material.lower()
            
            if exp_material == target_lower:
                material_score = 1.0  # Perfect match
            elif self._are_similar_materials(exp_material, target_lower):
                material_score = 0.6  # Similar materials (transfer learning!)
            else:
                material_score = 0.3  # Different but organic
            
            # 2. Thickness similarity (exponential decay)
            thickness_diff = abs(exp.get('materialThickness', 3.0) - target_thickness)
            thickness_score = np.exp(-thickness_diff / 1.5)  # Decay: 1.5mm
            
            # 3. Power similarity (exponential decay)
            power_diff = abs(exp.get('laserPower', 20) - target_power)
            power_score = np.exp(-power_diff / 10.0)  # Decay: 10W
            
            # 4. Quality score (0-1)
            quality = exp.get('qualityScores', {}).get('cutting', 5)
            quality_score = quality / 10.0
            
            # 5. Approve boost
            approve_count = exp.get('approveCount', 0)
            approve_boost = min(approve_count * 0.1, 1.0)
            
            # 6. Gold standard super boost
            is_gold = exp.get('dataSource') in ['researcher', 'researcher_import']
            gold_boost = 1.5 if is_gold else 1.0
            
            # Combined score (weighted)
            combined = (
                material_score * 0.35 +      # Material: 35%
                thickness_score * 0.30 +     # Thickness: 30%
                power_score * 0.20 +         # Power: 20%
                quality_score * 0.15         # Quality: 15%
            ) * (1 + approve_boost) * gold_boost
            
            scores.append(combined)
        
        # Softmax normalization
        scores = np.array(scores)
        exp_scores = np.exp(scores - np.max(scores))
        normalized = exp_scores / exp_scores.sum()
        
        logger.debug(f"📊 Similarity scores: min={scores.min():.3f}, max={scores.max():.3f}")
        
        return normalized
    
    def _are_similar_materials(self, mat1: str, mat2: str) -> bool:
        """Benzer malzeme grupları (transfer learning için)."""
        wood_group = ['ahşap', 'ahsap', 'wood', 'mdf']
        paper_group = ['kağıt', 'kagit', 'paper', 'karton', 'cardboard']
        fabric_group = ['kumaş', 'kumas', 'fabric', 'keçe', 'felt']
        leather_group = ['deri', 'leather']
        
        for group in [wood_group, paper_group, fabric_group, leather_group]:
            if mat1 in group and mat2 in group:
                return True
        return False
    
    def _weighted_average(
        self,
        experiments: List[Dict],
        weights: np.ndarray,
        process_type: str
    ) -> Dict:
        """Weighted average (domain adaptation)."""
        weighted_power = 0.0
        weighted_speed = 0.0
        passes_list = []
        
        for exp, weight in zip(experiments, weights):
            process_data = exp['processes'][process_type]
            weighted_power += process_data['power'] * weight
            weighted_speed += process_data['speed'] * weight
            passes_list.append((process_data['passes'], weight))
        
        # Passes: weighted median
        passes_sorted = sorted(passes_list, key=lambda x: x[0])
        cumulative_weight = 0.0
        median_passes = 1
        for passes_val, weight in passes_sorted:
            cumulative_weight += weight
            if cumulative_weight >= 0.5:
                median_passes = passes_val
                break
        
        return {
            'power': round(max(10, min(100, weighted_power)), 1),
            'speed': round(max(50, min(500, weighted_speed)), 0),
            'passes': max(1, min(20, median_passes))
        }
    
    def _scale_by_power(
        self,
        params: Dict,
        source_power: float,
        target_power: float
    ) -> Dict:
        """Power scaling (few-shot learning)."""
        power_ratio = target_power / source_power
        
        # Power percentage: inverse
        scaled_power = params['power'] / (power_ratio ** 0.4)
        
        # Speed: direct
        scaled_speed = params['speed'] * (power_ratio ** 0.3)
        
        # Passes: conditional
        scaled_passes = params['passes']
        if power_ratio < 0.7:
            scaled_passes += 1
        elif power_ratio > 1.3:
            scaled_passes = max(1, scaled_passes - 1)
        
        logger.info(f"⚖️ Power scaling: {source_power:.0f}W → {target_power:.0f}W")
        
        return {
            'power': round(max(10, min(100, scaled_power)), 1),
            'speed': round(max(50, min(500, scaled_speed)), 0),
            'passes': max(1, min(20, scaled_passes))
        }
    
    def _calculate_confidence(
        self,
        data_points: int,
        experiments: List[Dict],
        similarity_scores: np.ndarray,
        power_difference: float,
        was_scaled: bool
    ) -> float:
        """Confidence score calculation."""
        # Base from quantity
        if data_points >= 50:
            base = 0.90
        elif data_points >= 20:
            base = 0.85
        elif data_points >= 10:
            base = 0.75
        elif data_points >= 5:
            base = 0.68
        else:
            base = 0.60
        
        # Similarity factor
        similarity_factor = float(np.mean(similarity_scores))
        
        # Gold standard boost
        gold_ratio = sum(
            1 for e in experiments 
            if e.get('dataSource') in ['researcher', 'researcher_import']
        ) / len(experiments)
        gold_boost = 1.0 + (gold_ratio * 0.1)
        
        # Scaling penalty
        if was_scaled:
            if power_difference < 15:
                power_penalty = 0.95
            elif power_difference < 30:
                power_penalty = 0.85
            else:
                power_penalty = 0.75
        else:
            power_penalty = 1.0
        
        confidence = base * similarity_factor * gold_boost * power_penalty
        return round(min(0.95, max(0.55, confidence)), 2)
    
    def _generate_notes(
        self,
        data_points: int,
        confidence: float,
        experiments: List[Dict],
        process_type: str,
        was_scaled: bool,
        power_diff: float
    ) -> str:
        """Generate user-facing notes."""
        parts = []
        
        # Confidence
        if confidence >= 0.80:
            parts.append("✅ Yüksek güvenilirlik")
        elif confidence >= 0.65:
            parts.append("ℹ️ Orta güvenilirlik")
        else:
            parts.append("⚠️ Düşük güvenilirlik")
        
        # Data count
        parts.append(f"{data_points} benzer deney")
        
        # Scaling
        if was_scaled:
            parts.append(f"🔧 {power_diff:.0f}W güç farkı ölçeklendirildi")
        
        # Quality
        avg_quality = mean([
            e.get('qualityScores', {}).get(process_type, 5) 
            for e in experiments
        ])
        parts.append(f"Kalite: {avg_quality:.1f}/10")
        
        # Gold standard
        gold_count = sum(
            1 for e in experiments 
            if e.get('dataSource') in ['researcher', 'researcher_import']
        )
        if gold_count > 0:
            parts.append(f"🌟 {gold_count} gold standard")
        
        return " | ".join(parts)


# Global singleton
_ml_service = None

def get_ml_service() -> MLPredictionService:
    """Get or create ML service singleton."""
    global _ml_service
    if _ml_service is None:
        _ml_service = MLPredictionService()
    return _ml_service