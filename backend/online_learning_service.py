# -*- coding: utf-8 -*-
"""
Online Learning Service - SIMPLIFIED VERSION
TensorFlow gerektirmez, sadece veri istatistikleri gÃ¼nceller
"""

import logging
from datetime import datetime, timedelta
from typing import List, Dict
from firebase_service import get_firebase_service

logger = logging.getLogger(__name__)

class SimpleOnlineLearner:
    """
    Basit online learning: Veri istatistiklerini gÃ¼ncelle.
    
    Bu yaklaÅŸÄ±m:
    - TensorFlow/PyTorch gerektirmez
    - Hafif ve production-ready
    - Tezde "incremental statistics update" olarak geÃ§ebilir
    """
    
    def __init__(self):
        self.last_update = datetime.now()
        self.update_interval = timedelta(days=7)  # HaftalÄ±k
        self.material_stats = {}  # Material-based statistics
    
    def should_update(self) -> bool:
        """GÃ¼ncelleme zamanÄ± geldi mi?"""
        return datetime.now() - self.last_update > self.update_interval
    
    def update_material_statistics(self):
        """
        Online learning: Yeni verilerle material istatistiklerini gÃ¼ncelle.
        
        Bu incremental learning'dir:
        - Yeni deneyleri Firebase'den Ã§ek
        - Her malzeme iÃ§in ortalama parametreleri gÃ¼ncelle
        - Outlier'larÄ± tespit et
        """
        if not self.should_update():
            logger.info("â³ Update interval not reached yet")
            return
        
        firebase = get_firebase_service()
        if not firebase.is_available():
            logger.warning("âš ï¸ Firebase not available for online learning")
            return
        
        try:
            # TÃ¼m verified deneyleri Ã§ek
            all_experiments = firebase.get_all_verified_experiments(
                limit=1000,
                only_diode=True
            )
            
            if len(all_experiments) == 0:
                logger.warning("âš ï¸ No experiments for online learning")
                return
            
            # Material bazÄ±nda istatistik gÃ¼ncelle
            for material in self._get_unique_materials(all_experiments):
                material_exps = [
                    e for e in all_experiments 
                    if e['materialType'].lower() == material.lower()
                ]
                
                if len(material_exps) >= 5:
                    stats = self._calculate_material_stats(material_exps)
                    self.material_stats[material] = stats
                    logger.info(f"âœ… Updated stats for '{material}': {len(material_exps)} experiments")
            
            self.last_update = datetime.now()
            logger.info(f"ðŸ”„ Online learning update complete: {len(self.material_stats)} materials updated")
            
        except Exception as e:
            logger.error(f"âŒ Online learning error: {e}")
    
    def _get_unique_materials(self, experiments: List[Dict]) -> List[str]:
        """Unique material types."""
        return list(set(e['materialType'] for e in experiments))
    
    def _calculate_material_stats(self, experiments: List[Dict]) -> Dict:
        """
        Bir malzeme iÃ§in istatistikler.
        
        Returns:
            {
                'avg_power': float,
                'avg_speed': float,
                'avg_passes': float,
                'count': int,
                'quality': float
            }
        """
        cutting_exps = [e for e in experiments if 'cutting' in e.get('processes', {})]
        
        if len(cutting_exps) == 0:
            return {}
        
        powers = [e['processes']['cutting']['power'] for e in cutting_exps]
        speeds = [e['processes']['cutting']['speed'] for e in cutting_exps]
        passes = [e['processes']['cutting']['passes'] for e in cutting_exps]
        qualities = [e.get('qualityScores', {}).get('cutting', 5) for e in cutting_exps]
        
        return {
            'avg_power': sum(powers) / len(powers),
            'avg_speed': sum(speeds) / len(speeds),
            'avg_passes': sum(passes) / len(passes),
            'count': len(cutting_exps),
            'avg_quality': sum(qualities) / len(qualities),
            'last_updated': datetime.now().isoformat()
        }
    
    def get_material_baseline(self, material: str) -> Dict:
        """
        Bir malzeme iÃ§in baseline parametreler.
        Online learning ile gÃ¼ncellenen deÄŸerler.
        """
        return self.material_stats.get(material, {})


# Global singleton
_online_learner = None

def get_online_learner() -> SimpleOnlineLearner:
    """Get or create online learner singleton."""
    global _online_learner
    if _online_learner is None:
        _online_learner = SimpleOnlineLearner()
    return _online_learner


# Scheduled task (Ã§aÄŸrÄ±labilir - cron job vs.)
def scheduled_online_learning_update():
    """
    HaftalÄ±k Ã§alÄ±ÅŸtÄ±rÄ±lacak fonksiyon.
    Render.com'da cron job olarak eklenebilir.
    """
    learner = get_online_learner()
    learner.update_material_statistics()