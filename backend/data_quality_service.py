# -*- coding: utf-8 -*-
"""
Data Quality Service - Outlier Detection & Data Augmentation
Ensures high-quality training data for transfer learning
"""

import logging
import numpy as np
from typing import List, Dict, Tuple
from collections import Counter

logger = logging.getLogger(__name__)


class DataQualityService:
    """
    🛡️ Data Quality Control
    
    Features:
    - Outlier detection (IQR, Z-score)
    - Data validation
    - Synthetic data augmentation
    - Class imbalance handling
    """
    
    def __init__(self):
        self.outlier_stats = {
            'total_checked': 0,
            'outliers_detected': 0,
            'outliers_removed': 0
        }
        
        logger.info("✅ DataQualityService initialized")
    
    def detect_outliers(
        self,
        experiments: List[Dict],
        method: str = 'iqr',
        threshold: float = 3.0
    ) -> Tuple[List[Dict], List[Dict]]:
        """
        Detect and filter outliers
        
        Args:
            experiments: List of experiment dicts
            method: 'iqr' (Interquartile Range) or 'zscore'
            threshold: IQR multiplier (1.5-3.0) or Z-score threshold
        
        Returns:
            (clean_experiments, outliers)
        """
        logger.info(f"🔍 Detecting outliers with {method} method (threshold={threshold})...")
        
        self.outlier_stats['total_checked'] += len(experiments)
        
        if not experiments:
            return [], []
        
        # Extract numerical features for outlier detection
        features_matrix = []
        for exp in experiments:
            for process_type, params in exp.get('processes', {}).items():
                features_matrix.append([
                    exp.get('materialThickness', 0),
                    exp.get('laserPower', 0),
                    params.get('power', 0),
                    params.get('speed', 0),
                    params.get('passes', 0)
                ])
        
        features_matrix = np.array(features_matrix)
        
        if len(features_matrix) == 0:
            return experiments, []
        
        # Detect outliers
        if method == 'iqr':
            outlier_mask = self._detect_outliers_iqr(features_matrix, threshold)
        elif method == 'zscore':
            outlier_mask = self._detect_outliers_zscore(features_matrix, threshold)
        else:
            logger.warning(f"⚠️ Unknown method {method}, using IQR")
            outlier_mask = self._detect_outliers_iqr(features_matrix, threshold)
        
        # Map back to experiments (handle multiple processes per experiment)
        experiment_outlier_flags = []
        idx = 0
        for exp in experiments:
            n_processes = len(exp.get('processes', {}))
            if n_processes == 0:
                experiment_outlier_flags.append(False)
            else:
                # Mark as outlier if ANY process is outlier
                is_outlier = any(outlier_mask[idx:idx+n_processes])
                experiment_outlier_flags.append(is_outlier)
                idx += n_processes
        
        # Split
        clean = [exp for exp, is_out in zip(experiments, experiment_outlier_flags) if not is_out]
        outliers = [exp for exp, is_out in zip(experiments, experiment_outlier_flags) if is_out]
        
        self.outlier_stats['outliers_detected'] += len(outliers)
        
        logger.info(f"✅ Outlier detection complete:")
        logger.info(f"   Clean: {len(clean)}")
        logger.info(f"   Outliers: {len(outliers)} ({len(outliers)/len(experiments)*100:.1f}%)")
        
        return clean, outliers
    
    def _detect_outliers_iqr(
        self,
        features: np.ndarray,
        multiplier: float = 1.5
    ) -> np.ndarray:
        """
        IQR (Interquartile Range) method
        
        Outlier if: value < Q1 - multiplier*IQR or value > Q3 + multiplier*IQR
        """
        Q1 = np.percentile(features, 25, axis=0)
        Q3 = np.percentile(features, 75, axis=0)
        IQR = Q3 - Q1
        
        lower_bound = Q1 - multiplier * IQR
        upper_bound = Q3 + multiplier * IQR
        
        # Check each feature dimension
        outlier_mask = np.any(
            (features < lower_bound) | (features > upper_bound),
            axis=1
        )
        
        return outlier_mask
    
    def _detect_outliers_zscore(
        self,
        features: np.ndarray,
        threshold: float = 3.0
    ) -> np.ndarray:
        """
        Z-score method
        
        Outlier if: |z-score| > threshold
        """
        mean = np.mean(features, axis=0)
        std = np.std(features, axis=0)
        
        # Avoid division by zero
        std[std == 0] = 1.0
        
        z_scores = np.abs((features - mean) / std)
        
        # Check each feature dimension
        outlier_mask = np.any(z_scores > threshold, axis=1)
        
        return outlier_mask
    
    def validate_experiment(self, experiment: Dict) -> Tuple[bool, List[str]]:
        """
        Validate single experiment
        
        Returns:
            (is_valid, error_messages)
        """
        errors = []
        
        # Check required fields
        required = ['materialType', 'materialThickness', 'laserPower', 'processes']
        for field in required:
            if field not in experiment or not experiment[field]:
                errors.append(f"Missing required field: {field}")
        
        # Check value ranges
        if 'laserPower' in experiment:
            power = experiment['laserPower']
            if not (2 <= power <= 40):
                errors.append(f"Laser power out of range: {power}W (expected 2-40W)")
        
        if 'materialThickness' in experiment:
            thickness = experiment['materialThickness']
            if not (0.1 <= thickness <= 10):
                errors.append(f"Thickness out of range: {thickness}mm (expected 0.1-10mm)")
        
        # Check processes
        if 'processes' in experiment:
            for process_type, params in experiment['processes'].items():
                if 'power' in params:
                    if not (5 <= params['power'] <= 100):
                        errors.append(f"{process_type} power out of range: {params['power']}%")
                
                if 'speed' in params:
                    if not (50 <= params['speed'] <= 500):
                        errors.append(f"{process_type} speed out of range: {params['speed']} mm/min")
                
                if 'passes' in params:
                    if not (1 <= params['passes'] <= 20):
                        errors.append(f"{process_type} passes out of range: {params['passes']}")
        
        is_valid = len(errors) == 0
        
        if not is_valid:
            logger.warning(f"⚠️ Invalid experiment: {errors}")
        
        return is_valid, errors
    
    def augment_data(
        self,
        experiments: List[Dict],
        augmentation_factor: int = 2
    ) -> List[Dict]:
        """
        Generate synthetic training data via augmentation
        
        Methods:
        1. Thickness interpolation (±10%)
        2. Power scaling (±5W)
        3. Noise injection (Gaussian)
        
        Args:
            experiments: Original experiments
            augmentation_factor: How many synthetic samples per real sample
        
        Returns:
            augmented_experiments (includes originals)
        """
        logger.info(f"🔄 Augmenting data (factor={augmentation_factor})...")
        
        augmented = list(experiments)  # Keep originals
        
        for exp in experiments:
            for _ in range(augmentation_factor - 1):
                synthetic = self._create_synthetic_experiment(exp)
                if synthetic:
                    augmented.append(synthetic)
        
        logger.info(f"✅ Augmentation complete: {len(experiments)} → {len(augmented)}")
        
        return augmented
    
    def _create_synthetic_experiment(self, original: Dict) -> Optional[Dict]:
        """Create synthetic experiment by perturbing original"""
        import copy
        synthetic = copy.deepcopy(original)
        
        try:
            # Perturb thickness (±10%)
            thickness = synthetic.get('materialThickness', 3.0)
            thickness_scale = np.random.uniform(0.9, 1.1)
            synthetic['materialThickness'] = max(0.5, min(10.0, thickness * thickness_scale))
            
            # Perturb laser power (±10%)
            power = synthetic.get('laserPower', 20.0)
            power_scale = np.random.uniform(0.9, 1.1)
            synthetic['laserPower'] = max(2.0, min(40.0, power * power_scale))
            
            # Perturb process parameters
            for process_type, params in synthetic.get('processes', {}).items():
                # Power (±5%)
                if 'power' in params:
                    params['power'] = max(10, min(100, 
                        params['power'] * np.random.uniform(0.95, 1.05)
                    ))
                
                # Speed (±10%)
                if 'speed' in params:
                    params['speed'] = max(50, min(500,
                        params['speed'] * np.random.uniform(0.90, 1.10)
                    ))
                
                # Add Gaussian noise
                if 'power' in params:
                    params['power'] += np.random.normal(0, 2)  # σ=2%
                if 'speed' in params:
                    params['speed'] += np.random.normal(0, 10)  # σ=10 mm/min
            
            # Mark as synthetic
            synthetic['dataSource'] = synthetic.get('dataSource', 'user') + '_synthetic'
            
            return synthetic
            
        except Exception as e:
            logger.warning(f"⚠️ Failed to create synthetic experiment: {e}")
            return None
    
    def balance_classes(
        self,
        experiments: List[Dict],
        target_key: str = 'materialType',
        method: str = 'oversample'
    ) -> List[Dict]:
        """
        Handle class imbalance
        
        Args:
            experiments: Original experiments
            target_key: Which field to balance (e.g., 'materialType')
            method: 'oversample' or 'undersample'
        
        Returns:
            Balanced experiments
        """
        logger.info(f"⚖️ Balancing classes by '{target_key}' ({method})...")
        
        # Count class distribution
        class_counts = Counter(exp.get(target_key, 'unknown') for exp in experiments)
        
        logger.info(f"   Original distribution: {dict(class_counts)}")
        
        if method == 'oversample':
            # Oversample minority classes to match majority
            max_count = max(class_counts.values())
            balanced = []
            
            for class_value, count in class_counts.items():
                class_exps = [e for e in experiments if e.get(target_key) == class_value]
                
                # Duplicate to reach max_count
                n_needed = max_count - count
                if n_needed > 0:
                    # Random oversampling with replacement
                    oversampled = np.random.choice(class_exps, size=n_needed, replace=True).tolist()
                    balanced.extend(class_exps + oversampled)
                else:
                    balanced.extend(class_exps)
            
        elif method == 'undersample':
            # Undersample majority classes to match minority
            min_count = min(class_counts.values())
            balanced = []
            
            for class_value, count in class_counts.items():
                class_exps = [e for e in experiments if e.get(target_key) == class_value]
                
                # Random undersample
                if count > min_count:
                    undersampled = np.random.choice(class_exps, size=min_count, replace=False).tolist()
                    balanced.extend(undersampled)
                else:
                    balanced.extend(class_exps)
        
        else:
            logger.warning(f"⚠️ Unknown balancing method: {method}")
            return experiments
        
        # Verify
        balanced_counts = Counter(exp.get(target_key, 'unknown') for exp in balanced)
        logger.info(f"✅ Balanced distribution: {dict(balanced_counts)}")
        
        return balanced
    
    def get_quality_report(self) -> Dict:
        """Generate data quality report"""
        return {
            'outlier_detection': self.outlier_stats,
            'timestamp': str(np.datetime64('now'))
        }


# ===== GLOBAL SINGLETON =====
_quality_service = None

def get_quality_service() -> DataQualityService:
    """Get or create quality service singleton"""
    global _quality_service
    if _quality_service is None:
        _quality_service = DataQualityService()
    return _quality_service