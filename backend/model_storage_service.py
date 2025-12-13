# -*- coding: utf-8 -*-
"""
Firebase Storage Integration for Model Persistence
Saves/loads TensorFlow model to/from Firebase Storage
Project: LaserTuner ML API
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
    - save_model_to_storage() â†’ Upload model to Firebase Storage
    - load_model_from_storage() â†’ Download model from Firebase Storage
    
    Storage Location:
    - Bucket: lasertuner-59b92.firebasestorage.app
    - Path: ml_models/diode_laser_transfer_v1.h5
    """
    
    def __init__(self, bucket_name: Optional[str] = None):
        """
        Initialize Firebase Storage service
        
        Args:
            bucket_name: Firebase Storage bucket (e.g., 'your-app.appspot.com')
                        If None, uses default LaserTuner bucket
        """
        try:
            # Default bucket for LaserTuner project
            if bucket_name is None:
                bucket_name = "lasertuner-59b92.firebasestorage.app"
            
            self.bucket = storage.bucket(bucket_name)
            self.model_path = "ml_models/diode_laser_transfer_v1.h5"
            self.bucket_name = bucket_name
            
            logger.info(f"âœ… Firebase Storage initialized: {bucket_name}")
            logger.info(f"   Model path: {self.model_path}")
            
        except Exception as e:
            logger.error(f"âŒ Firebase Storage init failed: {e}")
            logger.exception("Full error:")
            self.bucket = None
            self.bucket_name = None
    
    def is_available(self) -> bool:
        """Check if Firebase Storage is available"""
        return self.bucket is not None
    
    def model_exists_in_storage(self) -> bool:
        """
        Check if model file exists in Firebase Storage
        
        Returns:
            True if model exists, False otherwise
        """
        if not self.is_available():
            logger.warning("âš ï¸ Storage not available, cannot check model existence")
            return False
        
        try:
            blob = self.bucket.blob(self.model_path)
            exists = blob.exists()
            
            if exists:
                logger.info(f"âœ… Model found in storage: {self.model_path}")
                # Log size info
                blob.reload()
                size_mb = blob.size / 1024 / 1024
                logger.info(f"   Size: {size_mb:.2f} MB")
            else:
                logger.info(f"â„¹ï¸ Model not found in storage: {self.model_path}")
            
            return exists
            
        except Exception as e:
            logger.error(f"âŒ Storage check failed: {e}")
            logger.exception("Full error:")
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
            logger.warning("âš ï¸ Firebase Storage not available")
            return False
        
        if not os.path.exists(local_model_path):
            logger.error(f"âŒ Local model not found: {local_model_path}")
            return False
        
        try:
            logger.info(f"ðŸ“¤ Uploading model to Firebase Storage...")
            logger.info(f"   From: {local_model_path}")
            logger.info(f"   To: gs://{self.bucket_name}/{self.model_path}")
            
            blob = self.bucket.blob(self.model_path)
            
            # Upload with metadata
            file_size = os.path.getsize(local_model_path)
            blob.metadata = {
                'uploaded_at': str(os.path.getmtime(local_model_path)),
                'file_size': str(file_size),
                'model_version': 'v1',
                'framework': 'tensorflow',
                'model_type': 'diode_laser_transfer_learning'
            }
            
            # Upload file
            blob.upload_from_filename(local_model_path)
            
            # Verify upload
            if blob.exists():
                logger.info(f"âœ… Model uploaded successfully to Firebase Storage")
                logger.info(f"   Path: {self.model_path}")
                logger.info(f"   Size: {file_size / 1024 / 1024:.2f} MB")
                logger.info(f"   Public URL: https://firebasestorage.googleapis.com/v0/b/{self.bucket_name}/o/{self.model_path.replace('/', '%2F')}?alt=media")
                return True
            else:
                logger.error("âŒ Upload failed: Model not found after upload")
                return False
            
        except Exception as e:
            logger.error(f"âŒ Model upload failed: {e}")
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
            logger.warning("âš ï¸ Firebase Storage not available")
            return False
        
        try:
            logger.info(f"ðŸ“¥ Downloading model from Firebase Storage...")
            logger.info(f"   From: gs://{self.bucket_name}/{self.model_path}")
            logger.info(f"   To: {local_model_path}")
            
            blob = self.bucket.blob(self.model_path)
            
            if not blob.exists():
                logger.warning(f"âš ï¸ Model not found in storage: {self.model_path}")
                return False
            
            # Create local directory if needed
            local_dir = os.path.dirname(local_model_path)
            if local_dir and not os.path.exists(local_dir):
                os.makedirs(local_dir, exist_ok=True)
                logger.info(f"   Created directory: {local_dir}")
            
            # Download to local
            blob.download_to_filename(local_model_path)
            
            # Verify download
            if os.path.exists(local_model_path):
                file_size = os.path.getsize(local_model_path)
                logger.info(f"âœ… Model downloaded successfully from Firebase Storage")
                logger.info(f"   Saved to: {local_model_path}")
                logger.info(f"   Size: {file_size / 1024 / 1024:.2f} MB")
                return True
            else:
                logger.error("âŒ Download failed: File not found after download")
                return False
            
        except Exception as e:
            logger.error(f"âŒ Model download failed: {e}")
            logger.exception("Full error:")
            return False
    
    def get_model_metadata(self) -> Optional[dict]:
        """
        Get model metadata from Firebase Storage
        
        Returns:
            Dict with metadata or None if not available
        """
        if not self.is_available():
            return None
        
        try:
            blob = self.bucket.blob(self.model_path)
            
            if not blob.exists():
                logger.info("â„¹ï¸ Model not found in storage, no metadata available")
                return None
            
            # Refresh metadata from storage
            blob.reload()
            
            metadata = {
                'exists': True,
                'path': self.model_path,
                'bucket': self.bucket_name,
                'size_bytes': blob.size,
                'size_mb': blob.size / 1024 / 1024,
                'updated': blob.updated,
                'created': blob.time_created,
                'content_type': blob.content_type,
                'custom_metadata': blob.metadata or {},
                'md5_hash': blob.md5_hash,
                'public_url': f"https://firebasestorage.googleapis.com/v0/b/{self.bucket_name}/o/{self.model_path.replace('/', '%2F')}?alt=media"
            }
            
            logger.info(f"ðŸ“Š Model metadata retrieved:")
            logger.info(f"   Size: {metadata['size_mb']:.2f} MB")
            logger.info(f"   Updated: {metadata['updated']}")
            
            return metadata
            
        except Exception as e:
            logger.error(f"âŒ Metadata fetch failed: {e}")
            logger.exception("Full error:")
            return None
    
    def delete_model_from_storage(self) -> bool:
        """
        Delete model from Firebase Storage
        
        Returns:
            True if successful, False otherwise
        """
        if not self.is_available():
            logger.warning("âš ï¸ Firebase Storage not available")
            return False
        
        try:
            blob = self.bucket.blob(self.model_path)
            
            if not blob.exists():
                logger.info("â„¹ï¸ Model not found in storage, nothing to delete")
                return True
            
            blob.delete()
            
            logger.info(f"âœ… Model deleted from Firebase Storage: {self.model_path}")
            return True
            
        except Exception as e:
            logger.error(f"âŒ Model deletion failed: {e}")
            logger.exception("Full error:")
            return False
    
    def get_storage_info(self) -> dict:
        """
        Get storage service information
        
        Returns:
            Dict with storage service info
        """
        return {
            'available': self.is_available(),
            'bucket_name': self.bucket_name,
            'model_path': self.model_path,
            'model_exists': self.model_exists_in_storage() if self.is_available() else False,
            'full_path': f"gs://{self.bucket_name}/{self.model_path}" if self.bucket_name else None
        }


# Global singleton
_storage_service = None

def get_storage_service(bucket_name: Optional[str] = None) -> ModelStorageService:
    """
    Get or create Firebase Storage service singleton
    
    Args:
        bucket_name: Optional custom bucket name. If None, uses LaserTuner default
    
    Returns:
        ModelStorageService instance
    """
    global _storage_service
    if _storage_service is None:
        _storage_service = ModelStorageService(bucket_name)
        logger.info("ðŸ“¦ Model Storage Service singleton created")
    return _storage_service


def reset_storage_service():
    """Reset storage service singleton (useful for testing)"""
    global _storage_service
    _storage_service = None
    logger.info("ðŸ”„ Model Storage Service singleton reset")