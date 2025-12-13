# -*- coding: utf-8 -*-
"""
Hybrid Transfer Learning Model for Diode Laser Parameter Prediction
Combines Image Features (CNN) + Numerical Features (Physical Properties)
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
    from tensorflow.keras.layers import (
        Input, Dense, Dropout, BatchNormalization, Concatenate,
        GlobalAveragePooling2D, Conv2D, MaxPooling2D
    )
    from tensorflow.keras.applications import EfficientNetB0
    from tensorflow.keras.optimizers import Adam
    from tensorflow.keras.callbacks import (
        EarlyStopping, ReduceLROnPlateau, ModelCheckpoint, TensorBoard
    )
    TF_AVAILABLE = True
    logger.info("✅ TensorFlow available for transfer learning")
except ImportError:
    TF_AVAILABLE = False
    logger.warning("⚠️ TensorFlow not available, transfer learning disabled")


class HybridDiodeLaserModel:
    """
    🔥 HYBRID TRANSFER LEARNING MODEL
    
    Architecture:
    ┌─────────────────────────────────────────┐
    │  INPUT 1: Image (224x224x3)            │
    │    ↓                                    │
    │  EfficientNetB0 (ImageNet pre-trained) │
    │    ↓                                    │
    │  GlobalAveragePooling                   │
    │    ↓                                    │
    │  Dense(128) - Image Features            │
    └─────────────────────────────────────────┘
                    ↓
    ┌─────────────────────────────────────────┐
    │  INPUT 2: Numerical (9 features)       │
    │    ↓                                    │
    │  Dense(64) - Physical Features          │
    └─────────────────────────────────────────┘
                    ↓
    ┌─────────────────────────────────────────┐
    │  FUSION: Concatenate                    │
    │    ↓                                    │
    │  Dense(256) + BN + Dropout              │
    │  Dense(128) + BN + Dropout              │
    │  Dense(64) + BN + Dropout               │
    └─────────────────────────────────────────┘
                    ↓
    ┌─────────────────────────────────────────┐
    │  OUTPUT HEADS (Multi-task)              │
    │    ├─ Power Head → Dense(32) → Output   │
    │    ├─ Speed Head → Dense(32) → Output   │
    │    └─ Passes Head → Dense(16) → Output  │
    └─────────────────────────────────────────┘
    """
    
    def __init__(
        self, 
        model_path: Optional[str] = None,
        use_images: bool = True,
        image_shape: Tuple[int, int, int] = (224, 224, 3)
    ):
        if not TF_AVAILABLE:
            raise RuntimeError("TensorFlow not available")
        
        self.model = None
        self.history = None
        self.is_trained = False
        self.use_images = use_images
        self.image_shape = image_shape
        self.version = "2.0.0"  # Hybrid version
        
        if model_path and os.path.exists(model_path):
            self.load_model(model_path)
            self.is_trained = True
            logger.info(f"✅ Loaded hybrid model from {model_path}")
        else:
            self.model = self._build_hybrid_model()
            logger.info(f"✅ Built new hybrid model (images={'ON' if use_images else 'OFF'})")
    
    def _build_hybrid_model(self) -> Model:
        """
        Build Hybrid CNN + MLP Model
        """
        inputs = []
        feature_branches = []
        
        # ===== BRANCH 1: IMAGE FEATURES (CNN) =====
        if self.use_images:
            image_input = Input(shape=self.image_shape, name='image_input')
            inputs.append(image_input)
            
            # Pre-trained EfficientNetB0 (ImageNet weights)
            base_cnn = EfficientNetB0(
                weights='imagenet',
                include_top=False,
                input_tensor=image_input
            )
            
            # Freeze early layers (transfer learning)
            for layer in base_cnn.layers[:100]:  # Freeze first 100 layers
                layer.trainable = False
            
            # Image feature extraction
            x_img = GlobalAveragePooling2D(name='image_pool')(base_cnn.output)
            x_img = Dense(128, activation='relu', name='image_dense')(x_img)
            x_img = BatchNormalization(name='image_bn')(x_img)
            x_img = Dropout(0.3, name='image_dropout')(x_img)
            
            feature_branches.append(x_img)
            logger.info("   🖼️ Image branch: EfficientNetB0 (pre-trained)")
        
        # ===== BRANCH 2: NUMERICAL FEATURES (MLP) =====
        numerical_input = Input(shape=(9,), name='numerical_input')
        inputs.append(numerical_input)
        
        x_num = Dense(64, activation='relu', name='numerical_dense_1')(numerical_input)
        x_num = BatchNormalization(name='numerical_bn_1')(x_num)
        x_num = Dropout(0.2, name='numerical_dropout_1')(x_num)
        
        x_num = Dense(32, activation='relu', name='numerical_dense_2')(x_num)
        x_num = BatchNormalization(name='numerical_bn_2')(x_num)
        
        feature_branches.append(x_num)
        logger.info("   🔢 Numerical branch: Deep MLP")
        
        # ===== FUSION LAYER =====
        if len(feature_branches) > 1:
            combined = Concatenate(name='fusion')(feature_branches)
            logger.info("   🔗 Fusion: Image + Numerical features")
        else:
            combined = feature_branches[0]
            logger.info("   🔗 Using only numerical features")
        
        # ===== SHARED REPRESENTATION LEARNING =====
        x = Dense(256, activation='relu', name='shared_dense_1')(combined)
        x = BatchNormalization(name='shared_bn_1')(x)
        x = Dropout(0.3, name='shared_dropout_1')(x)
        
        x = Dense(128, activation='relu', name='shared_dense_2')(x)
        x = BatchNormalization(name='shared_bn_2')(x)
        x = Dropout(0.2, name='shared_dropout_2')(x)
        
        x = Dense(64, activation='relu', name='shared_dense_3')(x)
        x = BatchNormalization(name='shared_bn_3')(x)
        x = Dropout(0.1, name='shared_dropout_3')(x)
        
        # ===== MULTI-TASK OUTPUT HEADS =====
        # Power prediction head
        power_head = Dense(32, activation='relu', name='power_head')(x)
        power_output = Dense(1, activation='sigmoid', name='power')(power_head)
        
        # Speed prediction head
        speed_head = Dense(32, activation='relu', name='speed_head')(x)
        speed_output = Dense(1, activation='sigmoid', name='speed')(speed_head)
        
        # Passes prediction head
        passes_head = Dense(16, activation='relu', name='passes_head')(x)
        passes_output = Dense(1, activation='sigmoid', name='passes')(passes_head)
        
        # Build model
        model = Model(
            inputs=inputs,
            outputs=[power_output, speed_output, passes_output],
            name=f'hybrid_diode_laser_v{self.version}'
        )
        
        return model
    
    def compile_model(self, learning_rate: float = 0.001):
        """Compile with multi-output loss"""
        self.model.compile(
            optimizer=Adam(learning_rate=learning_rate),
            loss={
                'power': 'mse',
                'speed': 'mse',
                'passes': 'mse'
            },
            loss_weights={
                'power': 1.0,    # Most critical
                'speed': 1.0,    # Critical
                'passes': 0.5    # Less critical
            },
            metrics={
                'power': ['mae', 'mse'],
                'speed': ['mae', 'mse'],
                'passes': ['mae']
            }
        )
        logger.info(f"✅ Model compiled (lr={learning_rate})")
    
    def train(
        self, 
        X_numerical: np.ndarray,
        y_power: np.ndarray, 
        y_speed: np.ndarray,
        y_passes: np.ndarray,
        X_images: Optional[np.ndarray] = None,
        epochs: int = 100,
        validation_split: float = 0.2,
        save_path: Optional[str] = None
    ) -> Dict:
        """
        Train hybrid model
        
        Args:
            X_numerical: Numerical features (N, 9)
            y_power, y_speed, y_passes: Targets (N, 1) normalized 0-1
            X_images: Images (N, 224, 224, 3) or None
            epochs: Training epochs
            validation_split: Validation ratio
            save_path: Path to save best model
        """
        logger.info(f"🔄 Training hybrid model...")
        logger.info(f"   Numerical: {X_numerical.shape}")
        if X_images is not None:
            logger.info(f"   Images: {X_images.shape}")
        
        self.compile_model()
        
        # Prepare inputs
        if self.use_images and X_images is not None:
            X_input = [X_images, X_numerical]
        else:
            X_input = X_numerical
        
        # Callbacks
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
                patience=7,
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
            
            # TensorBoard logs
            log_dir = os.path.join(
                os.path.dirname(save_path),
                'logs',
                f'run_{tf.timestamp()}'
            )
            callbacks.append(TensorBoard(log_dir=log_dir, histogram_freq=1))
        
        # Train
        history = self.model.fit(
            X_input,
            {'power': y_power, 'speed': y_speed, 'passes': y_passes},
            epochs=epochs,
            validation_split=validation_split,
            callbacks=callbacks,
            batch_size=min(32, len(X_numerical) // 4),
            verbose=1
        )
        
        self.history = history
        self.is_trained = True
        
        # Log final metrics
        final_metrics = {k: v[-1] for k, v in history.history.items() if 'val' in k}
        logger.info(f"✅ Training complete: {final_metrics}")
        
        return history.history
    
    def fine_tune(
        self,
        X_numerical: np.ndarray,
        y_power: np.ndarray,
        y_speed: np.ndarray,
        y_passes: np.ndarray,
        X_images: Optional[np.ndarray] = None,
        freeze_cnn: bool = True,
        epochs: int = 50
    ) -> Dict:
        """
        Fine-tune with new data
        
        Strategy:
        1. Freeze CNN (if images used)
        2. Train MLP + output heads (moderate LR)
        3. Optionally unfreeze CNN
        4. Full fine-tune (low LR)
        """
        logger.info(f"🔧 Fine-tuning hybrid model...")
        logger.info(f"   New samples: {len(X_numerical)}")
        logger.info(f"   Freeze CNN: {freeze_cnn}")
        
        # Prepare inputs
        if self.use_images and X_images is not None:
            X_input = [X_images, X_numerical]
        else:
            X_input = X_numerical
        
        # ===== PHASE 1: Frozen CNN (if applicable) =====
        if self.use_images and freeze_cnn:
            logger.info("🔒 Phase 1: Freezing CNN layers...")
            for layer in self.model.layers:
                if 'efficientnet' in layer.name.lower() or 'image' in layer.name:
                    layer.trainable = False
                    logger.info(f"   ❄️ Frozen: {layer.name}")
            
            self.compile_model(learning_rate=0.001)
            
            logger.info("🔄 Phase 1: Training MLP + heads...")
            self.model.fit(
                X_input,
                {'power': y_power, 'speed': y_speed, 'passes': y_passes},
                epochs=epochs // 2,
                validation_split=0.2,
                batch_size=min(32, len(X_numerical) // 4),
                verbose=0
            )
        
        # ===== PHASE 2: Full fine-tuning =====
        logger.info("🔓 Phase 2: Unfreezing all layers...")
        for layer in self.model.layers:
            if not layer.trainable:
                layer.trainable = True
                logger.info(f"   ✅ Unfrozen: {layer.name}")
        
        self.compile_model(learning_rate=0.0001)
        
        logger.info("🔄 Phase 2: Full fine-tuning...")
        history = self.model.fit(
            X_input,
            {'power': y_power, 'speed': y_speed, 'passes': y_passes},
            epochs=epochs,
            validation_split=0.2,
            batch_size=min(32, len(X_numerical) // 4),
            callbacks=[
                EarlyStopping(patience=10, restore_best_weights=True, verbose=1)
            ],
            verbose=1
        )
        
        self.is_trained = True
        logger.info(f"✅ Fine-tuning complete: val_loss={history.history['val_loss'][-1]:.4f}")
        
        return history.history
    
    def predict(
        self,
        X_numerical: np.ndarray,
        X_images: Optional[np.ndarray] = None
    ) -> Tuple[np.ndarray, np.ndarray, np.ndarray]:
        """
        Predict parameters
        
        Args:
            X_numerical: Features (N, 9)
            X_images: Images (N, 224, 224, 3) or None
        
        Returns:
            (power, speed, passes) each (N, 1) normalized 0-1
        """
        if not self.is_trained:
            logger.warning("⚠️ Model not trained, predictions may be random")
        
        if self.use_images and X_images is not None:
            X_input = [X_images, X_numerical]
        else:
            X_input = X_numerical
        
        predictions = self.model.predict(X_input, verbose=0)
        return predictions[0], predictions[1], predictions[2]
    
    def evaluate(
        self,
        X_numerical: np.ndarray,
        y_power: np.ndarray,
        y_speed: np.ndarray,
        y_passes: np.ndarray,
        X_images: Optional[np.ndarray] = None
    ) -> Dict:
        """Evaluate model performance"""
        if self.use_images and X_images is not None:
            X_input = [X_images, X_numerical]
        else:
            X_input = X_numerical
        
        results = self.model.evaluate(
            X_input,
            {'power': y_power, 'speed': y_speed, 'passes': y_passes},
            verbose=0,
            return_dict=True
        )
        
        logger.info(f"📊 Evaluation: {results}")
        return results
    
    def save_model(self, path: str):
        """Save model with metadata"""
        os.makedirs(os.path.dirname(path) if os.path.dirname(path) else '.', exist_ok=True)
        self.model.save(path)
        
        # Save metadata
        metadata = {
            'version': self.version,
            'use_images': self.use_images,
            'image_shape': self.image_shape,
            'is_trained': self.is_trained,
            'timestamp': str(tf.timestamp().numpy())
        }
        
        import json
        metadata_path = path.replace('.h5', '_metadata.json')
        with open(metadata_path, 'w') as f:
            json.dump(metadata, f, indent=2)
        
        logger.info(f"💾 Model saved: {path}")
        logger.info(f"💾 Metadata saved: {metadata_path}")
    
    def load_model(self, path: str):
        """Load model with metadata"""
        self.model = tf.keras.models.load_model(path)
        self.is_trained = True
        
        # Load metadata if exists
        metadata_path = path.replace('.h5', '_metadata.json')
        if os.path.exists(metadata_path):
            import json
            with open(metadata_path, 'r') as f:
                metadata = json.load(f)
            
            self.version = metadata.get('version', '1.0.0')
            self.use_images = metadata.get('use_images', False)
            self.image_shape = tuple(metadata.get('image_shape', (224, 224, 3)))
            
            logger.info(f"📂 Model loaded: {path}")
            logger.info(f"   Version: {self.version}")
            logger.info(f"   Images: {self.use_images}")
        else:
            logger.warning("⚠️ Metadata not found, using defaults")
    
    def get_model_summary(self) -> str:
        """Get model architecture summary"""
        import io
        stream = io.StringIO()
        self.model.summary(print_fn=lambda x: stream.write(x + '\n'))
        return stream.getvalue()


# ===== GLOBAL INSTANCE =====
_hybrid_model = None

def get_hybrid_model(
    model_path: Optional[str] = None,
    use_images: bool = False  # Default OFF (numerical only)
) -> Optional[HybridDiodeLaserModel]:
    """Get or create hybrid model singleton"""
    global _hybrid_model
    
    if not TF_AVAILABLE:
        logger.warning("⚠️ TensorFlow not available")
        return None
    
    if _hybrid_model is None:
        try:
            _hybrid_model = HybridDiodeLaserModel(
                model_path=model_path,
                use_images=use_images
            )
        except Exception as e:
            logger.error(f"❌ Failed to create hybrid model: {e}")
            return None
    
    return _hybrid_model


# ===== BACKWARD COMPATIBILITY =====
# Keep old function names for existing code
DiodeLaserTransferModel = HybridDiodeLaserModel
get_transfer_model = get_hybrid_model