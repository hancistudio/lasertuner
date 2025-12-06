# -*- coding: utf-8 -*-
"""
Firebase Storage Integration for Model Persistence
Saves/loads TensorFlow model to/from Firebase Storage
"""

import os
import logging
from typing import Optional
from firebase_admin import storage
import tempfile

logger = logging.getLogger(__name__)

class ModelStorageService:
    """
    Firebase Storage for ML model persistence
    
    Usage:
    - save_model_to_storage() → Upload model to Firebase Storage
    - load_model_from_storage() → Download model from Firebase Storage
    """
    
    def __init__(self, bucket_name: Optional[str] = None):
        """
        Initialize Firebase Storage service
        
        Args:
            bucket_name: Firebase Storage bucket (e.g., 'your-app.appspot.com')
        """
        try:
            self.bucket = storage.bucket(bucket_name)
            self.model_path = "ml_models/diode_laser_transfer_v1.h5"
            logger.info(f"✅ Firebase Storage initialized: {bucket_name}")
        except Exception as e:
            logger.error(f"❌ Firebase Storage init failed: {e}")
            self.bucket = None
    
    def is_available(self) -> bool:
        """Check if Firebase Storage is available"""
        return self.bucket is not None
    
    def model_exists_in_storage(self) -> bool:
        """Check if model file exists in Firebase Storage"""
        if not self.is_available():
            return False
        
        try:
            blob = self.bucket.blob(self.model_path)
            exists = blob.exists()
            logger.info(f"📦 Model in storage: {exists}")
            return exists
        except Exception as e:
            logger.error(f"❌ Storage check failed: {e}")
            return False
    
    def save_model_to_storage(self, local_model_path: str) -> bool:
        """
        Upload model from local disk to Firebase Storage
        
        Args:
            local_model_path: Path to local .h5 file (e.g., "models/diode_laser_transfer_v1.h5")
        
        Returns:
            True if successful, False otherwise
        """
        if not self.is_available():
            logger.warning("⚠️ Firebase Storage not available")
            return False
        
        if not os.path.exists(local_model_path):
            logger.error(f"❌ Local model not found: {local_model_path}")
            return False
        
        try:
            blob = self.bucket.blob(self.model_path)
            
            # Upload with metadata
            blob.metadata = {
                'uploaded_at': str(os.path.getmtime(local_model_path)),
                'file_size': str(os.path.getsize(local_model_path)),
                'model_version': 'v1'
            }
            
            blob.upload_from_filename(local_model_path)
            
            logger.info(f"✅ Model uploaded to Firebase Storage: {self.model_path}")
            logger.info(f"   Size: {os.path.getsize(local_model_path) / 1024 / 1024:.2f} MB")
            
            return True
            
        except Exception as e:
            logger.error(f"❌ Model upload failed: {e}")
            logger.exception("Full error:")
            return False
    
    def load_model_from_storage(self, local_model_path: str) -> bool:
        """
        Download model from Firebase Storage to local disk
        
        Args:
            local_model_path: Where to save the downloaded model (e.g., "models/diode_laser_transfer_v1.h5")
        
        Returns:
            True if successful, False otherwise
        """
        if not self.is_available():
            logger.warning("⚠️ Firebase Storage not available")
            return False
        
        try:
            blob = self.bucket.blob(self.model_path)
            
            if not blob.exists():
                logger.warning(f"⚠️ Model not found in storage: {self.model_path}")
                return False
            
            # Create local directory if needed
            os.makedirs(os.path.dirname(local_model_path) if os.path.dirname(local_model_path) else '.', exist_ok=True)
            
            # Download to local
            blob.download_to_filename(local_model_path)
            
            logger.info(f"✅ Model downloaded from Firebase Storage: {self.model_path}")
            logger.info(f"   Saved to: {local_model_path}")
            logger.info(f"   Size: {os.path.getsize(local_model_path) / 1024 / 1024:.2f} MB")
            
            return True
            
        except Exception as e:
            logger.error(f"❌ Model download failed: {e}")
            logger.exception("Full error:")
            return False
    
    def get_model_metadata(self) -> Optional[dict]:
        """Get model metadata from Firebase Storage"""
        if not self.is_available():
            return None
        
        try:
            blob = self.bucket.blob(self.model_path)
            if not blob.exists():
                return None
            
            blob.reload()  # Refresh metadata
            
            return {
                'size_mb': blob.size / 1024 / 1024,
                'updated': blob.updated,
                'content_type': blob.content_type,
                'metadata': blob.metadata
            }
        except Exception as e:
            logger.error(f"❌ Metadata fetch failed: {e}")
            return None


# Global singleton
_storage_service = None

def get_storage_service(bucket_name: Optional[str] = None) -> ModelStorageService:
    """Get or create Firebase Storage service singleton"""
    global _storage_service
    if _storage_service is None:
        _storage_service = ModelStorageService(bucket_name)
    return _storage_service