# -*- coding: utf-8 -*-
"""
Model Evaluation Service - Production Metrics & A/B Testing
Tracks model performance and user satisfaction
"""

import logging
import numpy as np
from typing import Dict, List, Tuple, Optional
from datetime import datetime, timedelta
from collections import defaultdict
import json
import os

logger = logging.getLogger(__name__)

try:
    from sklearn.metrics import (
        mean_absolute_error,
        mean_squared_error,
        r2_score
    )
    SKLEARN_AVAILABLE = True
except ImportError:
    SKLEARN_AVAILABLE = False
    logger.warning("⚠️ scikit-learn not available, using basic metrics")


class ModelEvaluator:
    """
    🎯 Model Performance Evaluation & Monitoring
    
    Features:
    - Train/Val/Test split evaluation
    - Cross-validation
    - Production metrics tracking
    - A/B testing comparison
    - User feedback integration
    """
    
    def __init__(self, metrics_log_path: str = "logs/model_metrics.json"):
        self.metrics_log_path = metrics_log_path
        self.metrics_history = self._load_metrics_history()
        
        # Production tracking
        self.predictions_count = 0
        self.user_feedback = defaultdict(list)  # {prediction_id: [feedback]}
        
        logger.info("✅ ModelEvaluator initialized")
    
    def _load_metrics_history(self) -> List[Dict]:
        """Load historical metrics from file"""
        if os.path.exists(self.metrics_log_path):
            try:
                with open(self.metrics_log_path, 'r') as f:
                    return json.load(f)
            except Exception as e:
                logger.warning(f"⚠️ Failed to load metrics history: {e}")
        return []
    
    def _save_metrics_history(self):
        """Save metrics to file"""
        try:
            os.makedirs(os.path.dirname(self.metrics_log_path), exist_ok=True)
            with open(self.metrics_log_path, 'w') as f:
                json.dump(self.metrics_history, f, indent=2)
        except Exception as e:
            logger.error(f"❌ Failed to save metrics: {e}")
    
    def evaluate_model(
        self,
        model,
        X_numerical: np.ndarray,
        y_power: np.ndarray,
        y_speed: np.ndarray,
        y_passes: np.ndarray,
        X_images: Optional[np.ndarray] = None,
        dataset_name: str = "validation"
    ) -> Dict:
        """
        Comprehensive model evaluation
        
        Args:
            model: Trained model
            X_numerical: Features (N, 9)
            y_power, y_speed, y_passes: True labels (N, 1) normalized
            X_images: Images or None
            dataset_name: 'train', 'validation', or 'test'
        
        Returns:
            Dict with all metrics
        """
        logger.info(f"📊 Evaluating model on {dataset_name} set ({len(X_numerical)} samples)...")
        
        # Get predictions
        pred_power, pred_speed, pred_passes = model.predict(X_numerical, X_images)
        
        # Denormalize for interpretable metrics
        y_power_actual = y_power * 100  # 0-100%
        y_speed_actual = y_speed * 500  # 0-500 mm/min
        y_passes_actual = np.round(y_passes * 20)  # 1-20
        
        pred_power_actual = pred_power * 100
        pred_speed_actual = pred_speed * 500
        pred_passes_actual = np.round(pred_passes * 20)
        
        # Calculate metrics
        metrics = {
            'dataset': dataset_name,
            'n_samples': len(X_numerical),
            'timestamp': datetime.utcnow().isoformat(),
            
            # Power metrics
            'power': self._calculate_regression_metrics(
                y_power_actual, pred_power_actual, 'Power (%)'
            ),
            
            # Speed metrics
            'speed': self._calculate_regression_metrics(
                y_speed_actual, pred_speed_actual, 'Speed (mm/min)'
            ),
            
            # Passes metrics (integer accuracy)
            'passes': self._calculate_integer_metrics(
                y_passes_actual, pred_passes_actual, 'Passes'
            ),
            
            # Overall loss (normalized)
            'overall_mse': float(np.mean([
                mean_squared_error(y_power, pred_power),
                mean_squared_error(y_speed, pred_speed),
                mean_squared_error(y_passes, pred_passes)
            ]))
        }
        
        logger.info(f"✅ Evaluation complete:")
        logger.info(f"   Power MAE: {metrics['power']['mae']:.2f}%")
        logger.info(f"   Speed MAE: {metrics['speed']['mae']:.1f} mm/min")
        logger.info(f"   Passes Acc±1: {metrics['passes']['accuracy_within_1']*100:.1f}%")
        
        # Save to history
        self.metrics_history.append(metrics)
        self._save_metrics_history()
        
        return metrics
    
    def _calculate_regression_metrics(
        self,
        y_true: np.ndarray,
        y_pred: np.ndarray,
        name: str
    ) -> Dict:
        """Calculate regression metrics"""
        if SKLEARN_AVAILABLE:
            mae = mean_absolute_error(y_true, y_pred)
            mse = mean_squared_error(y_true, y_pred)
            rmse = np.sqrt(mse)
            r2 = r2_score(y_true, y_pred)
        else:
            # Basic implementations
            mae = float(np.mean(np.abs(y_true - y_pred)))
            mse = float(np.mean((y_true - y_pred) ** 2))
            rmse = float(np.sqrt(mse))
            
            # R² = 1 - (SS_res / SS_tot)
            ss_res = np.sum((y_true - y_pred) ** 2)
            ss_tot = np.sum((y_true - np.mean(y_true)) ** 2)
            r2 = float(1 - (ss_res / ss_tot)) if ss_tot > 0 else 0.0
        
        return {
            'mae': float(mae),
            'mse': float(mse),
            'rmse': float(rmse),
            'r2': float(r2),
            'mean_error': float(np.mean(y_pred - y_true)),
            'std_error': float(np.std(y_pred - y_true))
        }
    
    def _calculate_integer_metrics(
        self,
        y_true: np.ndarray,
        y_pred: np.ndarray,
        name: str
    ) -> Dict:
        """Calculate metrics for integer outputs (passes)"""
        exact_match = np.sum(y_true.flatten() == y_pred.flatten()) / len(y_true)
        within_1 = np.sum(np.abs(y_true - y_pred) <= 1) / len(y_true)
        within_2 = np.sum(np.abs(y_true - y_pred) <= 2) / len(y_true)
        
        return {
            'exact_accuracy': float(exact_match),
            'accuracy_within_1': float(within_1),
            'accuracy_within_2': float(within_2),
            'mae': float(np.mean(np.abs(y_true - y_pred)))
        }
    
    def cross_validate(
        self,
        model_class,
        X_numerical: np.ndarray,
        y_power: np.ndarray,
        y_speed: np.ndarray,
        y_passes: np.ndarray,
        X_images: Optional[np.ndarray] = None,
        n_folds: int = 5
    ) -> Dict:
        """
        K-Fold Cross-Validation
        
        Returns:
            Dict with mean ± std for all metrics
        """
        logger.info(f"🔄 Running {n_folds}-fold cross-validation...")
        
        from sklearn.model_selection import KFold
        kf = KFold(n_splits=n_folds, shuffle=True, random_state=42)
        
        fold_metrics = []
        
        for fold_idx, (train_idx, val_idx) in enumerate(kf.split(X_numerical), 1):
            logger.info(f"   Fold {fold_idx}/{n_folds}...")
            
            # Split data
            X_num_train, X_num_val = X_numerical[train_idx], X_numerical[val_idx]
            y_pow_train, y_pow_val = y_power[train_idx], y_power[val_idx]
            y_spd_train, y_spd_val = y_speed[train_idx], y_speed[val_idx]
            y_pas_train, y_pas_val = y_passes[train_idx], y_passes[val_idx]
            
            X_img_train = X_images[train_idx] if X_images is not None else None
            X_img_val = X_images[val_idx] if X_images is not None else None
            
            # Train fresh model
            fold_model = model_class()
            fold_model.train(
                X_num_train, y_pow_train, y_spd_train, y_pas_train,
                X_images=X_img_train,
                epochs=50,
                validation_split=0.0,  # No internal validation
                save_path=None
            )
            
            # Evaluate on validation fold
            metrics = self.evaluate_model(
                fold_model,
                X_num_val, y_pow_val, y_spd_val, y_pas_val,
                X_images=X_img_val,
                dataset_name=f"fold_{fold_idx}"
            )
            
            fold_metrics.append(metrics)
        
        # Aggregate results
        cv_results = self._aggregate_cv_metrics(fold_metrics)
        
        logger.info(f"✅ Cross-validation complete:")
        logger.info(f"   Power MAE: {cv_results['power']['mae_mean']:.2f} ± {cv_results['power']['mae_std']:.2f}%")
        logger.info(f"   Speed MAE: {cv_results['speed']['mae_mean']:.1f} ± {cv_results['speed']['mae_std']:.1f} mm/min")
        
        return cv_results
    
    def _aggregate_cv_metrics(self, fold_metrics: List[Dict]) -> Dict:
        """Aggregate cross-validation results"""
        aggregated = {
            'n_folds': len(fold_metrics),
            'power': {},
            'speed': {},
            'passes': {}
        }
        
        for target in ['power', 'speed', 'passes']:
            for metric_name in fold_metrics[0][target].keys():
                values = [fm[target][metric_name] for fm in fold_metrics]
                aggregated[target][f'{metric_name}_mean'] = float(np.mean(values))
                aggregated[target][f'{metric_name}_std'] = float(np.std(values))
        
        return aggregated
    
    def compare_models(
        self,
        model_a,
        model_b,
        X_numerical: np.ndarray,
        y_power: np.ndarray,
        y_speed: np.ndarray,
        y_passes: np.ndarray,
        X_images: Optional[np.ndarray] = None,
        names: Tuple[str, str] = ("Model A", "Model B")
    ) -> Dict:
        """
        A/B Testing: Compare two models
        
        Returns:
            Dict with comparison results
        """
        logger.info(f"⚖️ A/B Testing: {names[0]} vs {names[1]}")
        
        # Evaluate both models
        metrics_a = self.evaluate_model(
            model_a, X_numerical, y_power, y_speed, y_passes,
            X_images, dataset_name=names[0]
        )
        
        metrics_b = self.evaluate_model(
            model_b, X_numerical, y_power, y_speed, y_passes,
            X_images, dataset_name=names[1]
        )
        
        # Compare
        comparison = {
            'model_a': names[0],
            'model_b': names[1],
            'winner': {},
            'differences': {}
        }
        
        for target in ['power', 'speed', 'passes']:
            mae_a = metrics_a[target]['mae']
            mae_b = metrics_b[target]['mae']
            
            comparison['winner'][target] = names[0] if mae_a < mae_b else names[1]
            comparison['differences'][f'{target}_mae_diff'] = abs(mae_a - mae_b)
            comparison['differences'][f'{target}_improvement_%'] = (
                ((mae_a - mae_b) / mae_a * 100) if mae_a > mae_b else 
                ((mae_b - mae_a) / mae_b * 100)
            )
        
        # Overall winner (by MSE)
        mse_a = metrics_a['overall_mse']
        mse_b = metrics_b['overall_mse']
        comparison['overall_winner'] = names[0] if mse_a < mse_b else names[1]
        comparison['overall_improvement_%'] = abs((mse_a - mse_b) / max(mse_a, mse_b) * 100)
        
        logger.info(f"✅ Winner: {comparison['overall_winner']} "
                   f"({comparison['overall_improvement_%']:.1f}% improvement)")
        
        return comparison
    
    def track_production_prediction(
        self,
        prediction_id: str,
        request_data: Dict,
        prediction_output: Dict,
        model_version: str
    ):
        """
        Track prediction in production
        
        Args:
            prediction_id: Unique ID
            request_data: Input parameters
            prediction_output: Model output
            model_version: Model version used
        """
        self.predictions_count += 1
        
        # Log to file for analytics
        log_entry = {
            'id': prediction_id,
            'timestamp': datetime.utcnow().isoformat(),
            'model_version': model_version,
            'request': request_data,
            'prediction': prediction_output,
            'feedback': None  # To be filled later
        }
        
        # Save to production log
        log_file = "logs/production_predictions.jsonl"
        try:
            os.makedirs(os.path.dirname(log_file), exist_ok=True)
            with open(log_file, 'a') as f:
                f.write(json.dumps(log_entry) + '\n')
        except Exception as e:
            logger.error(f"❌ Failed to log prediction: {e}")
    
    def add_user_feedback(
        self,
        prediction_id: str,
        feedback: Dict
    ):
        """
        Add user feedback for prediction
        
        Args:
            prediction_id: Prediction ID
            feedback: {
                'success': bool,
                'actual_power': float (optional),
                'actual_speed': float (optional),
                'rating': int (1-5),
                'comment': str (optional)
            }
        """
        feedback['timestamp'] = datetime.utcnow().isoformat()
        self.user_feedback[prediction_id].append(feedback)
        
        logger.info(f"📝 User feedback received for {prediction_id}")
    
    def get_user_satisfaction_rate(self, days: int = 30) -> float:
        """
        Calculate user satisfaction rate
        
        Args:
            days: Look back period
        
        Returns:
            Satisfaction rate (0-1)
        """
        cutoff = datetime.utcnow() - timedelta(days=days)
        
        total = 0
        satisfied = 0
        
        for feedbacks in self.user_feedback.values():
            for fb in feedbacks:
                fb_time = datetime.fromisoformat(fb['timestamp'])
                if fb_time >= cutoff:
                    total += 1
                    if fb.get('success', False) or fb.get('rating', 0) >= 4:
                        satisfied += 1
        
        if total == 0:
            return 0.0
        
        rate = satisfied / total
        logger.info(f"😊 User satisfaction (last {days} days): {rate*100:.1f}% ({satisfied}/{total})")
        return rate
    
    def generate_performance_report(self) -> Dict:
        """
        Generate comprehensive performance report
        
        Returns:
            Dict with all metrics and trends
        """
        if not self.metrics_history:
            return {'status': 'no_data'}
        
        latest = self.metrics_history[-1]
        
        report = {
            'timestamp': datetime.utcnow().isoformat(),
            'total_evaluations': len(self.metrics_history),
            'latest_metrics': latest,
            'production_predictions': self.predictions_count,
            'user_satisfaction_30d': self.get_user_satisfaction_rate(30),
            'trends': self._calculate_trends()
        }
        
        return report
    
    def _calculate_trends(self) -> Dict:
        """Calculate metric trends over time"""
        if len(self.metrics_history) < 2:
            return {}
        
        recent = self.metrics_history[-5:]  # Last 5 evaluations
        
        trends = {}
        for target in ['power', 'speed', 'passes']:
            mae_values = [m[target]['mae'] for m in recent if target in m]
            if len(mae_values) >= 2:
                trend = 'improving' if mae_values[-1] < mae_values[0] else 'degrading'
                change = ((mae_values[-1] - mae_values[0]) / mae_values[0] * 100)
                trends[target] = {
                    'trend': trend,
                    'change_%': float(change)
                }
        
        return trends


# ===== GLOBAL SINGLETON =====
_evaluator = None

def get_evaluator() -> ModelEvaluator:
    """Get or create evaluator singleton"""
    global _evaluator
    if _evaluator is None:
        _evaluator = ModelEvaluator()
    return _evaluator