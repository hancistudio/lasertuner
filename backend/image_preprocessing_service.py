# -*- coding: utf-8 -*-
"""
Image Preprocessing Service for Transfer Learning
Firebase Storage'dan fotoğrafları indirip EfficientNetB0 için hazırlar
"""

import logging
import numpy as np
from typing import List, Dict, Optional, Tuple
import tempfile
import os
from io import BytesIO

logger = logging.getLogger(__name__)

try:
    from PIL import Image
    import requests
    PIL_AVAILABLE = True
except ImportError:
    PIL_AVAILABLE = False
    logger.warning("⚠️ PIL not available, image preprocessing disabled")

try:
    import cv2
    CV2_AVAILABLE = True
except ImportError:
    CV2_AVAILABLE = False
    logger.warning("⚠️ OpenCV not available, using PIL only")


class ImagePreprocessor:
    """
    🖼️ Image Preprocessing for Transfer Learning
    
    Features:
    - Firebase Storage URL'lerinden fotoğraf indirme
    - EfficientNetB0 format (224x224x3)
    - Image augmentation (rotation, flip, brightness)
    - Batch processing
    - Cache support
    """
    
    def __init__(self, target_size: Tuple[int, int] = (224, 224)):
        self.target_size = target_size
        self.cache = {}  # URL -> preprocessed image
        self.stats = {
            'total_processed': 0,
            'cache_hits': 0,
            'download_errors': 0
        }
        
        if not PIL_AVAILABLE:
            logger.error("❌ PIL not available, image preprocessing disabled!")
        else:
            logger.info(f"✅ ImagePreprocessor initialized (target_size={target_size})")
    
    def is_available(self) -> bool:
        """Check if image preprocessing is available"""
        return PIL_AVAILABLE
    
    def download_image_from_url(self, url: str, timeout: int = 10) -> Optional[np.ndarray]:
        """
        Firebase Storage URL'den fotoğraf indir
        
        Args:
            url: Firebase Storage public URL
            timeout: Download timeout (seconds)
        
        Returns:
            numpy array (H, W, 3) RGB format or None
        """
        if not PIL_AVAILABLE:
            return None
        
        # Check cache
        if url in self.cache:
            self.stats['cache_hits'] += 1
            return self.cache[url]
        
        try:
            # Download
            response = requests.get(url, timeout=timeout, stream=True)
            response.raise_for_status()
            
            # Load image
            image = Image.open(BytesIO(response.content))
            
            # Convert to RGB (if RGBA, grayscale, etc.)
            if image.mode != 'RGB':
                image = image.convert('RGB')
            
            # To numpy
            image_array = np.array(image)
            
            # Cache
            self.cache[url] = image_array
            self.stats['total_processed'] += 1
            
            logger.debug(f"✅ Downloaded image from {url[:50]}... shape={image_array.shape}")
            
            return image_array
            
        except Exception as e:
            logger.warning(f"⚠️ Failed to download image from {url[:50]}...: {e}")
            self.stats['download_errors'] += 1
            return None
    
    def preprocess_for_efficientnet(
        self,
        image: np.ndarray,
        normalize: bool = True
    ) -> np.ndarray:
        """
        EfficientNetB0 için preprocessing
        
        Args:
            image: numpy array (H, W, 3)
            normalize: ImageNet normalization uygula
        
        Returns:
            numpy array (224, 224, 3) normalized
        """
        if not PIL_AVAILABLE:
            return None
        
        try:
            # PIL Image'a çevir
            if isinstance(image, np.ndarray):
                pil_image = Image.fromarray(image.astype('uint8'))
            else:
                pil_image = image
            
            # Resize to 224x224
            pil_image = pil_image.resize(self.target_size, Image.LANCZOS)
            
            # To numpy
            processed = np.array(pil_image, dtype=np.float32)
            
            # Normalize (ImageNet stats)
            if normalize:
                # EfficientNet preprocessing: scale to [0, 1]
                processed = processed / 255.0
            
            return processed
            
        except Exception as e:
            logger.error(f"❌ Preprocessing failed: {e}")
            return None
    
    def augment_image(
        self,
        image: np.ndarray,
        rotation_range: int = 15,
        flip_horizontal: bool = True,
        brightness_range: float = 0.2
    ) -> np.ndarray:
        """
        Image augmentation (data augmentation için)
        
        Args:
            image: numpy array (H, W, 3)
            rotation_range: ±degrees
            flip_horizontal: Random horizontal flip
            brightness_range: ±brightness factor
        
        Returns:
            Augmented image
        """
        if not PIL_AVAILABLE:
            return image
        
        try:
            pil_image = Image.fromarray(image.astype('uint8'))
            
            # Random rotation
            if rotation_range > 0:
                angle = np.random.uniform(-rotation_range, rotation_range)
                pil_image = pil_image.rotate(angle, resample=Image.BICUBIC, fillcolor=(255, 255, 255))
            
            # Random horizontal flip
            if flip_horizontal and np.random.random() > 0.5:
                pil_image = pil_image.transpose(Image.FLIP_LEFT_RIGHT)
            
            # Random brightness
            if brightness_range > 0:
                from PIL import ImageEnhance
                brightness_factor = np.random.uniform(1 - brightness_range, 1 + brightness_range)
                enhancer = ImageEnhance.Brightness(pil_image)
                pil_image = enhancer.enhance(brightness_factor)
            
            return np.array(pil_image)
            
        except Exception as e:
            logger.warning(f"⚠️ Augmentation failed: {e}")
            return image
    
    def load_experiment_images(
        self,
        experiment: Dict,
        augment: bool = False
    ) -> Optional[np.ndarray]:
        """
        Bir deneyin fotoğraflarını yükle
        
        Args:
            experiment: Firebase experiment dict with photoUrl1, photoUrl2
            augment: Data augmentation uygula
        
        Returns:
            numpy array (224, 224, 3) or None
        """
        if not PIL_AVAILABLE:
            return None
        
        # photoUrl1 (primary) veya photoUrl2 kullan
        photo_url = experiment.get('photoUrl1') or experiment.get('photoUrl2')
        
        if not photo_url:
            logger.debug("⚠️ No photo URL in experiment")
            return None
        
        # Download
        image = self.download_image_from_url(photo_url)
        
        if image is None:
            return None
        
        # Augment (if training)
        if augment:
            image = self.augment_image(image)
        
        # Preprocess
        processed = self.preprocess_for_efficientnet(image)
        
        return processed
    
    def load_batch_images(
        self,
        experiments: List[Dict],
        augment: bool = False,
        fallback_to_zeros: bool = True
    ) -> np.ndarray:
        """
        Batch olarak fotoğrafları yükle
        
        Args:
            experiments: List of experiment dicts
            augment: Data augmentation
            fallback_to_zeros: Foto yoksa zeros array kullan
        
        Returns:
            numpy array (N, 224, 224, 3)
        """
        if not PIL_AVAILABLE:
            if fallback_to_zeros:
                return np.zeros((len(experiments), *self.target_size, 3), dtype=np.float32)
            return None
        
        images = []
        
        for exp in experiments:
            image = self.load_experiment_images(exp, augment=augment)
            
            if image is not None:
                images.append(image)
            elif fallback_to_zeros:
                # Foto yok, zeros kullan (model çalışsın)
                images.append(np.zeros((*self.target_size, 3), dtype=np.float32))
            
        if len(images) == 0:
            return None
        
        batch = np.array(images, dtype=np.float32)
        
        logger.info(f"📦 Loaded batch: {batch.shape}")
        return batch
    
    def create_dummy_batch(self, batch_size: int) -> np.ndarray:
        """
        Dummy image batch (fotoğraf yoksa)
        
        Returns:
            numpy array (N, 224, 224, 3) all zeros
        """
        return np.zeros((batch_size, *self.target_size, 3), dtype=np.float32)
    
    def clear_cache(self):
        """Clear image cache"""
        self.cache.clear()
        logger.info("🗑️ Image cache cleared")
    
    def get_stats(self) -> Dict:
        """Get preprocessing statistics"""
        return {
            'total_processed': self.stats['total_processed'],
            'cache_hits': self.stats['cache_hits'],
            'cache_size': len(self.cache),
            'download_errors': self.stats['download_errors'],
            'cache_hit_rate': (
                self.stats['cache_hits'] / self.stats['total_processed']
                if self.stats['total_processed'] > 0 else 0.0
            )
        }


# ===== GLOBAL SINGLETON =====
_image_preprocessor = None

def get_image_preprocessor() -> ImagePreprocessor:
    """Get or create image preprocessor singleton"""
    global _image_preprocessor
    if _image_preprocessor is None:
        _image_preprocessor = ImagePreprocessor()
    return _image_preprocessor