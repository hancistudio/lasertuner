# ===== backend/transfer_learning_model.py =====
import tensorflow as tf
from tensorflow.keras.applications import EfficientNetB0
from tensorflow.keras.layers import Dense, GlobalAveragePooling2D, Concatenate, Input
from tensorflow.keras.models import Model

class DiodeLaserPredictor:
    def __init__(self):
        # 1. Image branch (CNN)
        image_input = Input(shape=(224, 224, 3), name='image_input')
        base_model = EfficientNetB0(weights='imagenet', include_top=False)
        x = base_model(image_input)
        x = GlobalAveragePooling2D()(x)
        image_features = Dense(128, activation='relu')(x)
        
        # 2. Physical features branch
        physical_input = Input(shape=(5,), name='physical_input')  
        # [thickness, laserPower, density, melt_point, thermal_conductivity]
        physical_features = Dense(64, activation='relu')(physical_input)
        
        # 3. Fusion
        combined = Concatenate()([image_features, physical_features])
        x = Dense(256, activation='relu')(combined)
        x = Dropout(0.3)(x)
        
        # 4. Multi-output regression
        power_output = Dense(1, activation='linear', name='power')(x)
        speed_output = Dense(1, activation='linear', name='speed')(x)
        passes_output = Dense(1, activation='linear', name='passes')(x)
        
        self.model = Model(
            inputs=[image_input, physical_input],
            outputs=[power_output, speed_output, passes_output]
        )
        
    def train(self, image_data, physical_data, labels):
        self.model.compile(
            optimizer='adam',
            loss={'power': 'mse', 'speed': 'mse', 'passes': 'mse'},
            loss_weights={'power': 1.0, 'speed': 1.0, 'passes': 0.5}
        )
        
        history = self.model.fit(
            [image_data, physical_data],
            [labels['power'], labels['speed'], labels['passes']],
            epochs=50,
            validation_split=0.2,
            callbacks=[EarlyStopping(patience=5)]
        )
        return history