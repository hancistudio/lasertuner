# -*- coding: utf-8 -*-
"""
Transfer Learning Model for Diode Laser Parameter Prediction
Uses only numerical features (no images)
Trained on Firebase crowdsourced data
"""

import numpy as np
import logging
from typing import Dict, Tuple, List, Optional
import os

logger = logging.getLogger(__name__)

# Try TensorFlow import
try:
    import tensorflow as tf
    from tensorflow.keras.models import Model
    from tensorflow.keras.layers import Input, Dense, Dropout, BatchNormalization
    from tensorflow.keras.optimizers import Adam
    from tensorflow.keras.callbacks import EarlyStopping, ReduceLROnPlateau, ModelCheckpoint
    TF_AVAILABLE = True
    logger.info("✅ TensorFlow available for transfer learning")
except ImportError:
    TF_AVAILABLE = False
    logger.warning("⚠️ TensorFlow not available, transfer learning disabled")


class DiodeLaserTransferModel:
    """
    Transfer Learning Model for Diode Laser
    
    Architecture:
    - Input: 9 numerical features (material properties + process type)
    - Deep MLP with transfer learning layers
    - Multi-output regression (power, speed, passes)
    
    Transfer Learning Strategy:
    1. Pre-train on synthetic/physics-based data (optional)
    2. Fine-tune on real experimental data (Firebase crowdsourced)
    3. Continuous online learning with new data
    """
    
    def __init__(self, model_path: Optional[str] = None):
        if not TF_AVAILABLE:
            raise RuntimeError("TensorFlow not available, cannot use transfer learning")
        
        self.model = None
        self.history = None
        self.is_trained = False
        
        if model_path and os.path.exists(model_path):
            self.load_model(model_path)
            self.is_trained = True
            logger.info(f"✅ Loaded pre-trained model from {model_path}")
        else:
            self.model = self._build_model()
            logger.info("✅ Built new transfer learning model architecture")
    
    def _build_model(self) -> Model:
        """
        Build deep MLP for transfer learning
        
        Architecture:
        - Deep feature extraction layers (transfer learning component)
        - Batch normalization for stable training
        - Dropout for regularization
        - Task-specific output heads (fine-tuning component)
        """
        # Input layer (9 numerical features)
        input_features = Input(shape=(9,), name='physical_features')
        
        # ===== TRANSFER LEARNING LAYERS (Feature Extraction) =====
        x = Dense(256, activation='relu', name='transfer_dense_1')(input_features)
        x = BatchNormalization(name='transfer_bn_1')(x)
        x = Dropout(0.3, name='transfer_dropout_1')(x)
        
        x = Dense(128, activation='relu', name='transfer_dense_2')(x)
        x = BatchNormalization(name='transfer_bn_2')(x)
        x = Dropout(0.2, name='transfer_dropout_2')(x)
        
        x = Dense(64, activation='relu', name='transfer_dense_3')(x)
        x = BatchNormalization(name='transfer_bn_3')(x)
        x = Dropout(0.1, name='transfer_dropout_3')(x)
        
        # ===== TASK-SPECIFIC OUTPUT HEADS =====
        # Power prediction head
        power_head = Dense(32, activation='relu', name='power_head_dense')(x)
        power_output = Dense(1, activation='sigmoid', name='power')(power_head)
        
        # Speed prediction head
        speed_head = Dense(32, activation='relu', name='speed_head_dense')(x)
        speed_output = Dense(1, activation='sigmoid', name='speed')(speed_head)
        
        # Passes prediction head
        passes_head = Dense(16, activation='relu', name='passes_head_dense')(x)
        passes_output = Dense(1, activation='sigmoid', name='passes')(passes_head)
        
        # Build model
        model = Model(
            inputs=input_features,
            outputs=[power_output, speed_output, passes_output],
            name='diode_laser_transfer_model'
        )
        
        return model
    
    def compile_model(self, learning_rate: float = 0.001):
        """
        Compile model with multi-output loss
        
        Loss weights:
        - Power: Most critical (1.0)
        - Speed: Critical (1.0)
        - Passes: Less critical (0.5)
        """
        self.model.compile(
            optimizer=Adam(learning_rate=learning_rate),
            loss={
                'power': 'mse',
                'speed': 'mse',
                'passes': 'mse'
            },
            loss_weights={
                'power': 1.0,
                'speed': 1.0,
                'passes': 0.5
            },
            metrics={
                'power': ['mae', 'mse'],
                'speed': ['mae', 'mse'],
                'passes': ['mae']
            }
        )
        logger.info(f"✅ Model compiled with learning_rate={learning_rate}")
    
def train(self, X: np.ndarray, y_power: np.ndarray, y_speed: np.ndarray, 
          y_passes: np.ndarray, sample_weights: np.ndarray = None,  # ✅ YENİ parametre
          epochs: int = 100, validation_split: float = 0.2,
          save_path: Optional[str] = None) -> Dict:
    """
    Train model from scratch with Firebase data
    
    Args:
        X: Features (N, 9)
        y_power: Power targets normalized 0-1 (N, 1)
        y_speed: Speed targets normalized 0-1 (N, 1)
        y_passes: Passes targets normalized 0-1 (N, 1)
        sample_weights: Quality weights (N,) - ✅ YENİ
        epochs: Training epochs
        validation_split: Validation ratio
        save_path: Path to save best model
    
    Returns:
        Training history dict
    """
    if self.model is None:
        raise ValueError("Model not built")
    
    logger.info(f"🔄 Training model with {len(X)} samples...")
    logger.info(f"   Features shape: {X.shape}")
    logger.info(f"   Targets: power {y_power.shape}, speed {y_speed.shape}, passes {y_passes.shape}")
    
    # ✅ YENİ: Sample weights log
    if sample_weights is not None:
        logger.info(f"   Sample weights: min={sample_weights.min():.2f}, max={sample_weights.max():.2f}, mean={sample_weights.mean():.2f}")
    
    self.compile_model()
    
    callbacks = [
        EarlyStopping(
            monitor='val_loss',
            patience=15,
            restore_best_weights=True,
            verbose=1
        ),
        ReduceLROnPlateau(
            monitor='val_loss',
            factor=0.5,
            patience=5,
            min_lr=1e-6,
            verbose=1
        )
    ]
    
    if save_path:
        os.makedirs(os.path.dirname(save_path) if os.path.dirname(save_path) else '.', exist_ok=True)
        callbacks.append(
            ModelCheckpoint(
                save_path,
                monitor='val_loss',
                save_best_only=True,
                verbose=1
            )
        )
    
    history = self.model.fit(
        X,
        {'power': y_power, 'speed': y_speed, 'passes': y_passes},
        epochs=epochs,
        validation_split=validation_split,
        callbacks=callbacks,
        batch_size=min(32, len(X) // 4),
        sample_weight=sample_weights,  # ✅ YENİ: Quality weights
        verbose=1
    )
    
    self.history = history
    self.is_trained = True
    logger.info("✅ Training completed successfully")
    
    # Log final metrics
    final_metrics = {k: v[-1] for k, v in history.history.items() if 'val' in k}
    logger.info(f"📊 Final validation metrics: {final_metrics}")
    
    return history.history

def fine_tune(self, X: np.ndarray, y_power: np.ndarray, y_speed: np.ndarray,
              y_passes: np.ndarray, sample_weights: np.ndarray = None,  # ✅ YENİ
              freeze_layers: int = 3, epochs: int = 50):
    """
    Fine-tune pre-trained model with new Firebase data
    
    Args:
        X: New features (N, 9)
        y_power, y_speed, y_passes: New targets (N, 1)
        sample_weights: Quality weights (N,) - ✅ YENİ
        freeze_layers: Number of early layers to freeze initially
        epochs: Fine-tuning epochs
    """
    logger.info(f"🔧 Fine-tuning model with {len(X)} new samples...")
    logger.info(f"   Strategy: Freeze first {freeze_layers} layers → train → unfreeze → fine-tune")
    
    # ✅ YENİ: Sample weights log
    if sample_weights is not None:
        logger.info(f"   Sample weights: min={sample_weights.min():.2f}, max={sample_weights.max():.2f}")
    
    # ===== PHASE 1: Frozen Transfer Learning =====
    logger.info("📌 Phase 1: Freezing transfer layers...")
    frozen_count = 0
    for layer in self.model.layers:
        if 'transfer' in layer.name and frozen_count < freeze_layers:
            layer.trainable = False
            frozen_count += 1
            logger.info(f"   ❄️ Frozen: {layer.name}")
    
    self.compile_model(learning_rate=0.001)
    
    logger.info("🔄 Phase 1: Training with frozen layers...")
    self.model.fit(
        X,
        {'power': y_power, 'speed': y_speed, 'passes': y_passes},
        epochs=epochs // 2,
        validation_split=0.2,
        batch_size=min(32, len(X) // 4),
        sample_weight=sample_weights,  # ✅ YENİ
        verbose=0
    )
    
    # ===== PHASE 2: Full Fine-Tuning =====
    logger.info("🔓 Phase 2: Unfreezing all layers...")
    for layer in self.model.layers:
        if not layer.trainable:
            layer.trainable = True
            logger.info(f"   ✅ Unfrozen: {layer.name}")
    
    self.compile_model(learning_rate=0.0001)
    
    logger.info("🔄 Phase 2: Fine-tuning all layers...")
    history = self.model.fit(
        X,
        {'power': y_power, 'speed': y_speed, 'passes': y_passes},
        epochs=epochs,
        validation_split=0.2,
        batch_size=min(32, len(X) // 4),
        sample_weight=sample_weights,  # ✅ YENİ
        callbacks=[
            EarlyStopping(patience=10, restore_best_weights=True, verbose=1)
        ],
        verbose=1
    )
    
    self.is_trained = True
    logger.info("✅ Fine-tuning completed successfully")
    
    # Log improvement
    final_loss = history.history['val_loss'][-1]
    logger.info(f"📊 Final validation loss after fine-tuning: {final_loss:.4f}")
    
    return history.history
    
def fine_tune(self, X: np.ndarray, y_power: np.ndarray, y_speed: np.ndarray,
              y_passes: np.ndarray, sample_weights: np.ndarray = None,  # ✅ YENİ
              freeze_layers: int = 3, epochs: int = 50):
    """
    Fine-tune pre-trained model with new Firebase data
    
    Args:
        X: New features (N, 9)
        y_power, y_speed, y_passes: New targets (N, 1)
        sample_weights: Quality weights (N,) - ✅ YENİ
        freeze_layers: Number of early layers to freeze initially
        epochs: Fine-tuning epochs
    """
    logger.info(f"🔧 Fine-tuning model with {len(X)} new samples...")
    logger.info(f"   Strategy: Freeze first {freeze_layers} layers → train → unfreeze → fine-tune")
    
    # ✅ YENİ: Sample weights log
    if sample_weights is not None:
        logger.info(f"   Sample weights: min={sample_weights.min():.2f}, max={sample_weights.max():.2f}")
    
    # ===== PHASE 1: Frozen Transfer Learning =====
    logger.info("📌 Phase 1: Freezing transfer layers...")
    frozen_count = 0
    for layer in self.model.layers:
        if 'transfer' in layer.name and frozen_count < freeze_layers:
            layer.trainable = False
            frozen_count += 1
            logger.info(f"   ❄️ Frozen: {layer.name}")
    
    self.compile_model(learning_rate=0.001)
    
    logger.info("🔄 Phase 1: Training with frozen layers...")
    self.model.fit(
        X,
        {'power': y_power, 'speed': y_speed, 'passes': y_passes},
        epochs=epochs // 2,
        validation_split=0.2,
        batch_size=min(32, len(X) // 4),
        sample_weight=sample_weights,  # ✅ YENİ
        verbose=0
    )
    
    # ===== PHASE 2: Full Fine-Tuning =====
    logger.info("🔓 Phase 2: Unfreezing all layers...")
    for layer in self.model.layers:
        if not layer.trainable:
            layer.trainable = True
            logger.info(f"   ✅ Unfrozen: {layer.name}")
    
    self.compile_model(learning_rate=0.0001)
    
    logger.info("🔄 Phase 2: Fine-tuning all layers...")
    history = self.model.fit(
        X,
        {'power': y_power, 'speed': y_speed, 'passes': y_passes},
        epochs=epochs,
        validation_split=0.2,
        batch_size=min(32, len(X) // 4),
        sample_weight=sample_weights,  # ✅ YENİ
        callbacks=[
            EarlyStopping(patience=10, restore_best_weights=True, verbose=1)
        ],
        verbose=1
    )
    
    self.is_trained = True
    logger.info("✅ Fine-tuning completed successfully")
    
    # Log improvement
    final_loss = history.history['val_loss'][-1]
    logger.info(f"📊 Final validation loss after fine-tuning: {final_loss:.4f}")
    
    return history.history
    
    def predict(self, X: np.ndarray) -> Tuple[np.ndarray, np.ndarray, np.ndarray]:
        """
        Predict parameters
        
        Args:
            X: Features (N, 9) - normalized
        
        Returns:
            (power, speed, passes) each shape (N, 1) - normalized 0-1
        """
        if not self.is_trained:
            logger.warning("⚠️ Model not trained yet, predictions may be random")
        
        predictions = self.model.predict(X, verbose=0)
        return predictions[0], predictions[1], predictions[2]
    
    def evaluate(self, X: np.ndarray, y_power: np.ndarray, y_speed: np.ndarray,
                 y_passes: np.ndarray) -> Dict:
        """
        Evaluate model performance
        
        Returns:
            Dict with metrics: loss, mae, mse for each output
        """
        results = self.model.evaluate(
            X,
            {'power': y_power, 'speed': y_speed, 'passes': y_passes},
            verbose=0,
            return_dict=True
        )
        
        logger.info(f"📊 Evaluation results: {results}")
        return results
    
    def save_model(self, path: str):
        """Save model to file"""
        os.makedirs(os.path.dirname(path) if os.path.dirname(path) else '.', exist_ok=True)
        self.model.save(path)
        logger.info(f"💾 Model saved to {path}")
    
    def load_model(self, path: str):
        """Load model from file"""
        self.model = tf.keras.models.load_model(path)
        self.is_trained = True
        logger.info(f"📂 Model loaded from {path}")
    
    def get_model_summary(self) -> str:
        """Get model architecture summary"""
        import io
        stream = io.StringIO()
        self.model.summary(print_fn=lambda x: stream.write(x + '\n'))
        return stream.getvalue()


# Global instance
_transfer_model = None

def get_transfer_model(model_path: Optional[str] = None) -> Optional[DiodeLaserTransferModel]:
    """Get or create transfer model singleton"""
    global _transfer_model
    
    if not TF_AVAILABLE:
        logger.warning("⚠️ TensorFlow not available, transfer learning disabled")
        return None
    
    if _transfer_model is None:
        try:
            _transfer_model = DiodeLaserTransferModel(model_path)
        except Exception as e:
            logger.error(f"❌ Failed to create transfer model: {e}")
            return None
    
    return _transfer_model