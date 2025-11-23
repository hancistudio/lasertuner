# -*- coding: utf-8 -*-
"""
Firebase Service for LaserTuner ML API - DIODE LASER EDITION
Fetches diode laser experiment data from Firestore
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
    """Service for interacting with Firebase Firestore - Diode Laser optimized"""
    
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
                try:
                    import json
                    cred_dict = json.loads(private_key) if private_key else {}
                    
                    if 'private_key' in cred_dict:
                        cred = credentials.Certificate(cred_dict)
                    else:
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
        thickness_tolerance: float = 1.5,
        min_results: int = 3,
        max_laser_power: float = 40.0
    ) -> List[Dict]:
        """
        Fetch similar DIODE LASER experiments from Firestore
        
        Args:
            material_type: Material type (e.g., "Ahşap", "MDF")
            thickness: Material thickness in mm
            thickness_tolerance: +/- tolerance for thickness matching
            min_results: Minimum number of results to return
            max_laser_power: Maximum laser power (filters out CO2/Fiber lasers)
        
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
            docs = query.limit(200).stream()
            
            # Filter by thickness AND laser power in memory
            experiments = []
            min_thickness = thickness - thickness_tolerance
            max_thickness = thickness + thickness_tolerance
            
            for doc in docs:
                data = doc.to_dict()
                exp_thickness = data.get('materialThickness', 0)
                laser_power = data.get('laserPower', 0)
                
                # Check if it's a diode laser (2-40W) and thickness matches
                if (min_thickness <= exp_thickness <= max_thickness and 
                    2 <= laser_power <= max_laser_power):
                    
                    experiments.append({
                        'id': doc.id,
                        'materialType': data.get('materialType'),
                        'materialThickness': exp_thickness,
                        'laserPower': laser_power,
                        'machineBrand': data.get('machineBrand'),
                        'processes': data.get('processes', {}),
                        'qualityScores': data.get('qualityScores', {}),
                        'approveCount': data.get('approveCount', 0),
                        'rejectCount': data.get('rejectCount', 0),
                        'dataSource': data.get('dataSource'),
                    })
            
            logger.info(
                f"📊 Found {len(experiments)} similar DIODE experiments for "
                f"{material_type} {thickness}mm (±{thickness_tolerance}mm, ≤{max_laser_power}W)"
            )
            
            return experiments
            
        except Exception as e:
            logger.error(f"❌ Error fetching experiments: {e}")
            return []
    
    def get_all_verified_experiments(
        self, 
        limit: int = 1000,
        only_diode: bool = True
    ) -> List[Dict]:
        """
        Get all verified experiments for model training
        
        Args:
            limit: Maximum number of experiments to fetch
            only_diode: If True, only fetch diode laser experiments (2-40W)
        
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
                laser_power = data.get('laserPower', 0)
                
                # Filter for diode lasers if requested
                if only_diode and not (2 <= laser_power <= 40):
                    continue
                
                experiments.append({
                    'id': doc.id,
                    'materialType': data.get('materialType'),
                    'materialThickness': data.get('materialThickness'),
                    'laserPower': laser_power,
                    'machineBrand': data.get('machineBrand'),
                    'processes': data.get('processes', {}),
                    'qualityScores': data.get('qualityScores', {}),
                    'dataSource': data.get('dataSource'),
                })
            
            logger.info(
                f"📊 Fetched {len(experiments)} verified experiments "
                f"({'diode only' if only_diode else 'all types'})"
            )
            return experiments
            
        except Exception as e:
            logger.error(f"❌ Error fetching all experiments: {e}")
            return []
    
    def get_statistics(self, only_diode: bool = True) -> Dict:
        """
        Get database statistics
        
        Args:
            only_diode: If True, only count diode laser experiments
        """
        if not self.is_available():
            return {
                'total_experiments': 0,
                'verified_experiments': 0,
                'diode_experiments': 0,
                'materials': {},
                'available': False
            }
        
        try:
            # Get all experiments
            all_docs = self.db.collection('experiments').limit(2000).stream()
            
            total = 0
            verified = 0
            diode_count = 0
            materials = {}
            power_distribution = {'diode': 0, 'co2': 0, 'fiber': 0, 'unknown': 0}
            
            for doc in all_docs:
                total += 1
                data = doc.to_dict()
                laser_power = data.get('laserPower', 0)
                
                # Classify by power
                if 2 <= laser_power <= 40:
                    power_distribution['diode'] += 1
                    diode_count += 1
                elif 40 < laser_power <= 200:
                    power_distribution['co2'] += 1
                elif laser_power > 200:
                    power_distribution['fiber'] += 1
                else:
                    power_distribution['unknown'] += 1
                
                if data.get('verificationStatus') == 'verified':
                    verified += 1
                
                material = data.get('materialType', 'Unknown')
                
                # Only count diode materials if only_diode is True
                if only_diode:
                    if 2 <= laser_power <= 40:
                        materials[material] = materials.get(material, 0) + 1
                else:
                    materials[material] = materials.get(material, 0) + 1
            
            return {
                'total_experiments': total,
                'verified_experiments': verified,
                'diode_experiments': diode_count,
                'materials': materials,
                'power_distribution': power_distribution,
                'available': True,
                'timestamp': datetime.utcnow().isoformat()
            }
            
        except Exception as e:
            logger.error(f"❌ Error getting statistics: {e}")
            return {
                'total_experiments': 0,
                'verified_experiments': 0,
                'diode_experiments': 0,
                'materials': {},
                'available': False,
                'error': str(e)
            }
    
    def get_diode_machine_brands(self) -> List[Dict]:
        """Get list of diode laser machine brands in database"""
        if not self.is_available():
            return []
        
        try:
            experiments_ref = self.db.collection('experiments')
            docs = experiments_ref.limit(1000).stream()
            
            brands = {}
            for doc in docs:
                data = doc.to_dict()
                laser_power = data.get('laserPower', 0)
                
                # Only diode lasers
                if 2 <= laser_power <= 40:
                    brand = data.get('machineBrand', 'Unknown')
                    if brand not in brands:
                        brands[brand] = {
                            'count': 0,
                            'avg_power': 0,
                            'powers': []
                        }
                    brands[brand]['count'] += 1
                    brands[brand]['powers'].append(laser_power)
            
            # Calculate averages
            result = []
            for brand, info in brands.items():
                result.append({
                    'brand': brand,
                    'count': info['count'],
                    'avg_power': round(sum(info['powers']) / len(info['powers']), 1),
                    'min_power': min(info['powers']),
                    'max_power': max(info['powers'])
                })
            
            # Sort by count
            result.sort(key=lambda x: x['count'], reverse=True)
            
            logger.info(f"📊 Found {len(result)} diode laser brands")
            return result
            
        except Exception as e:
            logger.error(f"❌ Error getting machine brands: {e}")
            return []


# Global instance
_firebase_service = None

def get_firebase_service() -> FirebaseService:
    """Get or create Firebase service singleton"""
    global _firebase_service
    if _firebase_service is None:
        _firebase_service = FirebaseService()
    return _firebase_service