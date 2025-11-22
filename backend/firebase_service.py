# -*- coding: utf-8 -*-
"""
Firebase Service for LaserTuner ML API
Fetches experiment data from Firestore
"""

import os
import logging
from typing import List, Dict, Optional
from datetime import datetime
import firebase_admin
from firebase_admin import credentials, firestore
from google.cloud.firestore_v1.base_query import FieldFilter

logger = logging.getLogger(__name__)

class FirebaseService:
    """Service for interacting with Firebase Firestore"""
    
    def __init__(self):
        """Initialize Firebase Admin SDK"""
        self.db = None
        self.initialized = False
        self._initialize_firebase()
    
    def _initialize_firebase(self):
        """Initialize Firebase Admin SDK with credentials"""
        try:
            if firebase_admin._apps:
                self.db = firestore.client()
                self.initialized = True
                logger.info("✅ Firebase already initialized")
                return
            
            # Method 1: Try multiple secret file paths
            possible_paths = [
                '/etc/secrets/serviceAccountKey.json',
                'serviceAccountKey.json',
                './serviceAccountKey.json',
                os.path.join(os.getcwd(), 'serviceAccountKey.json'),
            ]
            
            for cred_path in possible_paths:
                if os.path.exists(cred_path):
                    logger.info(f"🔍 Found credentials at: {cred_path}")
                    cred = credentials.Certificate(cred_path)
                    firebase_admin.initialize_app(cred)
                    self.db = firestore.client()
                    self.initialized = True
                    logger.info(f"✅ Firebase initialized from {cred_path}")
                    return
            
            # Method 2: Environment Variables
            project_id = os.getenv('FIREBASE_PROJECT_ID')
            private_key = os.getenv('FIREBASE_PRIVATE_KEY')
            client_email = os.getenv('FIREBASE_CLIENT_EMAIL')
            
            if project_id and client_email:
                # Eğer private_key JSON string ise
                try:
                    import json
                    cred_dict = json.loads(private_key) if private_key else {}
                    
                    if 'private_key' in cred_dict:
                        # Tam JSON verildi
                        cred = credentials.Certificate(cred_dict)
                    else:
                        # Sadece key değerleri verildi
                        cred = credentials.Certificate({
                            "type": "service_account",
                            "project_id": project_id,
                            "private_key": private_key.replace('\\n', '\n') if private_key else '',
                            "client_email": client_email,
                            "token_uri": "https://oauth2.googleapis.com/token",
                        })
                    
                    firebase_admin.initialize_app(cred)
                    self.db = firestore.client()
                    self.initialized = True
                    logger.info(f"✅ Firebase initialized with env vars for {project_id}")
                    return
                except json.JSONDecodeError:
                    # Private key doğrudan string
                    if private_key and client_email:
                        cred = credentials.Certificate({
                            "type": "service_account",
                            "project_id": project_id,
                            "private_key": private_key.replace('\\n', '\n'),
                            "client_email": client_email,
                            "token_uri": "https://oauth2.googleapis.com/token",
                        })
                        
                        firebase_admin.initialize_app(cred)
                        self.db = firestore.client()
                        self.initialized = True
                        logger.info(f"✅ Firebase initialized with env vars for {project_id}")
                        return
            
            logger.warning("⚠️ Firebase not initialized - no credentials found")
            logger.warning(f"⚠️ Checked paths: {possible_paths}")
            
        except Exception as e:
            logger.error(f"❌ Firebase initialization error: {e}")
            logger.exception("Full error:")
            self.initialized = False
    
    def is_available(self) -> bool:
        """Check if Firebase service is available"""
        return self.initialized and self.db is not None
    
    def get_similar_experiments(
        self,
        material_type: str,
        thickness: float,
        thickness_tolerance: float = 2.0,
        min_results: int = 5
    ) -> List[Dict]:
        """
        Fetch similar experiments from Firestore
        
        Args:
            material_type: Material type (e.g., "Ahşap", "MDF")
            thickness: Material thickness in mm
            thickness_tolerance: +/- tolerance for thickness matching
            min_results: Minimum number of results to return
        
        Returns:
            List of experiment dictionaries
        """
        if not self.is_available():
            logger.warning("Firebase not available, returning empty list")
            return []
        
        try:
            # Normalize material type for search
            material_normalized = material_type.lower().strip()
            
            # Build query
            experiments_ref = self.db.collection('experiments')
            
            # Filter by material type
            query = experiments_ref.where(
                filter=FieldFilter('materialType', '==', material_type)
            )
            
            # Only get verified experiments
            query = query.where(
                filter=FieldFilter('verificationStatus', '==', 'verified')
            )
            
            # Execute query
            docs = query.limit(100).stream()
            
            # Filter by thickness in memory (Firestore range queries are limited)
            experiments = []
            min_thickness = thickness - thickness_tolerance
            max_thickness = thickness + thickness_tolerance
            
            for doc in docs:
                data = doc.to_dict()
                exp_thickness = data.get('materialThickness', 0)
                
                if min_thickness <= exp_thickness <= max_thickness:
                    experiments.append({
                        'id': doc.id,
                        'materialType': data.get('materialType'),
                        'materialThickness': exp_thickness,
                        'laserPower': data.get('laserPower'),
                        'processes': data.get('processes', {}),
                        'qualityScores': data.get('qualityScores', {}),
                        'approveCount': data.get('approveCount', 0),
                        'rejectCount': data.get('rejectCount', 0),
                    })
            
            logger.info(
                f"📊 Found {len(experiments)} similar experiments for "
                f"{material_type} {thickness}mm (±{thickness_tolerance}mm)"
            )
            
            return experiments
            
        except Exception as e:
            logger.error(f"❌ Error fetching experiments: {e}")
            return []
    
    def get_all_verified_experiments(self, limit: int = 1000) -> List[Dict]:
        """
        Get all verified experiments for model training
        
        Args:
            limit: Maximum number of experiments to fetch
        
        Returns:
            List of all verified experiments
        """
        if not self.is_available():
            return []
        
        try:
            experiments_ref = self.db.collection('experiments')
            query = experiments_ref.where(
                filter=FieldFilter('verificationStatus', '==', 'verified')
            ).limit(limit)
            
            docs = query.stream()
            experiments = []
            
            for doc in docs:
                data = doc.to_dict()
                experiments.append({
                    'id': doc.id,
                    'materialType': data.get('materialType'),
                    'materialThickness': data.get('materialThickness'),
                    'laserPower': data.get('laserPower'),
                    'machineBrand': data.get('machineBrand'),
                    'processes': data.get('processes', {}),
                    'qualityScores': data.get('qualityScores', {}),
                    'dataSource': data.get('dataSource'),
                })
            
            logger.info(f"📊 Fetched {len(experiments)} verified experiments")
            return experiments
            
        except Exception as e:
            logger.error(f"❌ Error fetching all experiments: {e}")
            return []
    
    def get_statistics(self) -> Dict:
        """Get database statistics"""
        if not self.is_available():
            return {
                'total_experiments': 0,
                'verified_experiments': 0,
                'materials': {},
                'available': False
            }
        
        try:
            # Get all experiments
            all_docs = self.db.collection('experiments').limit(1000).stream()
            
            total = 0
            verified = 0
            materials = {}
            
            for doc in all_docs:
                total += 1
                data = doc.to_dict()
                
                if data.get('verificationStatus') == 'verified':
                    verified += 1
                
                material = data.get('materialType', 'Unknown')
                materials[material] = materials.get(material, 0) + 1
            
            return {
                'total_experiments': total,
                'verified_experiments': verified,
                'materials': materials,
                'available': True,
                'timestamp': datetime.utcnow().isoformat()
            }
            
        except Exception as e:
            logger.error(f"❌ Error getting statistics: {e}")
            return {
                'total_experiments': 0,
                'verified_experiments': 0,
                'materials': {},
                'available': False,
                'error': str(e)
            }


# Global instance
_firebase_service = None

def get_firebase_service() -> FirebaseService:
    """Get or create Firebase service singleton"""
    global _firebase_service
    if _firebase_service is None:
        _firebase_service = FirebaseService()
    return _firebase_service