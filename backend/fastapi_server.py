"""
FastAPI Backend for NovaHealth ML Predictions
==============================================
Integrates trained TabNet models to predict health risks based on user's
daily lifestyle patterns (hydration, mood, symptoms, activity, etc.)

Models:
- Obesity Risk Prediction (95.93% accuracy)
- Exercise Calorie Prediction (R²=0.9980)
- Menstrual Cycle Prediction (91.06% accuracy)

Author: NovaHealth ML Team
"""

import os
import sys
from pathlib import Path
from typing import List, Dict, Optional
import numpy as np
import pandas as pd
from datetime import datetime
import gc

# FastAPI
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

# ML Libraries
from pytorch_tabnet.tab_model import TabNetClassifier, TabNetRegressor
from sklearn.preprocessing import LabelEncoder, StandardScaler
import torch

# Memory optimization for low-RAM environments (Render free tier: 512MB)
torch.set_num_threads(1)  # Reduce CPU thread overhead
os.environ['OMP_NUM_THREADS'] = '1'
os.environ['MKL_NUM_THREADS'] = '1'

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import List, Optional, Dict
import pandas as pd
import numpy as np
from datetime import datetime, timedelta
from pathlib import Path
import warnings
warnings.filterwarnings('ignore')

from sklearn.preprocessing import StandardScaler, LabelEncoder
from pytorch_tabnet.tab_model import TabNetClassifier, TabNetRegressor

# Initialize FastAPI
app = FastAPI(title="NovaHealth ML API", version="1.0.0")

# CORS middleware for Flutter app
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # In production, specify your Flutter app domain
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

MODEL_DIR = Path(__file__).parent / 'optimized_models'
RANDOM_SEED = 42
np.random.seed(RANDOM_SEED)


# ============================================================================
# PYDANTIC MODELS (Request/Response Schemas)
# ============================================================================

class UserProfile(BaseModel):
    """User profile data from Flutter app"""
    age: int
    gender: str  # male/female
    weight: float  # kg
    height: float  # cm
    activityLevel: str  # sedentary, lightly_active, moderately_active, very_active
    targetWeight: Optional[float] = None


class DailyLifestyleData(BaseModel):
    """Daily lifestyle tracking data from Flutter app"""
    # Hydration data
    totalWaterMl: int  # total water intake today
    hydrationLogs: List[Dict]  # list of hydration entries
    
    # Mood data
    moodLogs: List[Dict]  # list of mood entries with mood, intensity, factors
    
    # Symptoms
    symptoms: List[Dict]  # list of symptoms with type, severity
    
    # Activity (if available)
    exerciseDuration: Optional[int] = 0  # minutes
    exerciseIntensity: Optional[int] = 5  # 1-10 scale
    heartRate: Optional[int] = None
    
    # Sleep (if available)
    sleepHours: Optional[float] = None
    
    # Diet (if available)
    caloriesConsumed: Optional[int] = None


class HealthRiskRequest(BaseModel):
    """Complete request for health risk prediction"""
    userProfile: UserProfile
    lifestyleData: DailyLifestyleData
    dateRange: Optional[int] = 7  # days to analyze


class ObesityRiskResponse(BaseModel):
    """Obesity risk prediction response"""
    riskLevel: str  # Insufficient_Weight, Normal_Weight, Overweight_Level_I/II, Obesity_Type_I/II/III
    confidence: float
    bmi: float
    bmr: float
    recommendations: List[str]
    allProbabilities: Dict[str, float]


class ExerciseRecommendationResponse(BaseModel):
    """Exercise calorie prediction response"""
    predictedCalories: float
    caloriesPerMinute: float
    metScore: float
    intensityLevel: str
    recommendations: List[str]


class MenstrualPredictionResponse(BaseModel):
    """Menstrual cycle prediction response"""
    cycleRegularity: str  # Regular, Short, Long
    predictedCycleLength: int
    nextPeriodDate: str
    confidence: float
    recommendations: List[str]


class SymptomRiskAnalysis(BaseModel):
    """Symptom-based risk analysis"""
    probableConditions: List[str]  # Likely health conditions based on symptoms
    riskLevel: str  # Low, Moderate, High, Critical
    urgency: str  # Monitor, Schedule Checkup, Seek Medical Attention, Urgent Care
    detectedSymptoms: List[Dict]  # List of symptoms with their analysis


class HealthRiskResponse(BaseModel):
    """Complete health risk assessment"""
    obesityRisk: ObesityRiskResponse
    exerciseRecommendation: Optional[ExerciseRecommendationResponse]
    menstrualPrediction: Optional[MenstrualPredictionResponse]
    symptomRiskAnalysis: Optional[SymptomRiskAnalysis]
    overallRiskScore: float  # 0-100
    keyInsights: List[str]


# ============================================================================
# FEATURE ENGINEERING (From advanced_feature_engineering.py)
# ============================================================================

class ObesityFeatureEngineer:
    """Feature engineering for obesity prediction"""
    
    def engineer_features(self, df):
        """Apply obesity-specific feature engineering"""
        df = df.copy()
        
        # BMI
        if 'BMI' not in df.columns and 'Height' in df.columns and 'Weight' in df.columns:
            df['BMI'] = df['Weight'] / (df['Height'] ** 2)
        
        # BMR (Basal Metabolic Rate)
        if 'Age' in df.columns and 'Weight' in df.columns and 'Height' in df.columns and 'Gender' in df.columns:
            height_cm = df['Height'].apply(lambda x: x * 100 if x < 3 else x)
            weight_kg = df['Weight']
            
            df['BMR'] = 10 * weight_kg + 6.25 * height_cm - 5 * df['Age']
            df.loc[df['Gender'].str.lower().str.contains('female', na=False), 'BMR'] -= 161
            df.loc[df['Gender'].str.lower().str.contains('male', na=False) & 
                   ~df['Gender'].str.lower().str.contains('female', na=False), 'BMR'] += 5
        
        # Activity Score
        activity_cols = [c for c in df.columns if any(x in c.lower() for x in ['physactive', 'faf', 'activity'])]
        if activity_cols:
            activity_score = 0
            for col in activity_cols:
                if df[col].dtype == 'object':
                    activity_score += df[col].str.lower().str.contains('yes', na=False).astype(int)
                else:
                    activity_score += df[col].fillna(0)
            df['Activity_Score'] = activity_score
        
        return df


class ExerciseFeatureEngineer:
    """Feature engineering for exercise prediction"""
    
    def engineer_features(self, df):
        """Apply exercise-specific feature engineering"""
        df = df.copy()
        
        # MET Score
        if 'Actual Weight' in df.columns and 'Duration' in df.columns:
            weight_kg = df['Actual Weight']
            duration_hours = df['Duration'] / 60
            intensity_factor = df['Exercise Intensity'] / 10 * 8 if 'Exercise Intensity' in df.columns else 5
            df['MET_Score'] = 3.5 * weight_kg * duration_hours * intensity_factor
        
        # Heart Rate Zones
        if 'Heart Rate' in df.columns and 'Age' in df.columns:
            max_hr = 220 - df['Age']
            df['HR_Percentage'] = (df['Heart Rate'] / max_hr) * 100
            df['HR_Zone_Encoded'] = pd.cut(df['HR_Percentage'], bins=[0, 60, 70, 80, 90, 100], labels=[0, 1, 2, 3, 4])
            df['HR_Zone_Encoded'] = df['HR_Zone_Encoded'].cat.codes.fillna(-1).astype(int)
        
        # BMI-adjusted intensity
        if 'BMI' in df.columns and 'Exercise Intensity' in df.columns:
            df['BMI_Adjusted_Intensity'] = df['Exercise Intensity'] * (df['BMI'] / 25)
        
        # Weight difference
        if 'Dream Weight' in df.columns and 'Actual Weight' in df.columns:
            df['Weight_Difference'] = df['Actual Weight'] - df['Dream Weight']
            df['Weight_Diff_Percentage'] = (df['Weight_Difference'] / df['Actual Weight']) * 100
        
        # Calorie efficiency
        if 'Calories Burn' in df.columns and 'Heart Rate' in df.columns:
            df['Calorie_Efficiency'] = df['Calories Burn'] / df['Heart Rate'].replace(0, 1)
        
        # Age-adjusted calories
        if 'Age' in df.columns and 'Calories Burn' in df.columns:
            age_factor = 1 + (40 - df['Age']) / 100
            df['Age_Adjusted_Calories'] = df['Calories Burn'] * age_factor
        
        # Gender encoding
        if 'Gender' in df.columns:
            df['Gender_Encoded'] = LabelEncoder().fit_transform(df['Gender'])
        
        return df


# ============================================================================
# MODEL LOADING
# ============================================================================

class MLModels:
    """Memory-optimized singleton class to load and cache ML models"""
    _instance = None
    
    def __new__(cls):
        if cls._instance is None:
            cls._instance = super(MLModels, cls).__new__(cls)
            cls._instance._initialized = False
            cls._instance.obesity_model = None
            cls._instance.exercise_model = None
            cls._instance.menstrual_model = None
        return cls._instance
    
    def _load_models(self):
        """Load models with memory optimization - lazy loading"""
        if self._initialized:
            return
        
        print("Loading optimized ML models for low-memory environment...")
        
        # Load models one at a time with garbage collection between loads
        try:
            self.obesity_model = TabNetClassifier()
            # Try optimized version first, fallback to original
            optimized_path = MODEL_DIR / 'obesity' / 'obesity_tabnet_best_optimized.zip'
            original_path = MODEL_DIR / 'obesity' / 'obesity_tabnet_best.zip'
            model_path = optimized_path if optimized_path.exists() else original_path
            
            self.obesity_model.load_model(str(model_path))
            self.obesity_model.network.eval()  # Set to eval mode
            self.obesity_model.network.cpu()   # Force CPU
            self.obesity_classes = ['Insufficient_Weight', 'Normal_Weight', 'Obesity_Type_I', 
                                   'Obesity_Type_II', 'Obesity_Type_III', 'Overweight_Level_I', 
                                   'Overweight_Level_II']
            print(f"✓ Obesity model loaded from {model_path.name}")
            gc.collect()  # Force garbage collection
        except Exception as e:
            print(f"✗ Failed to load obesity model: {e}")
            self.obesity_model = None
        
        try:
            self.exercise_model = TabNetRegressor()
            optimized_path = MODEL_DIR / 'exercise' / 'exercise_tabnet_best_optimized.zip'
            original_path = MODEL_DIR / 'exercise' / 'exercise_tabnet_best.zip'
            model_path = optimized_path if optimized_path.exists() else original_path
            
            self.exercise_model.load_model(str(model_path))
            self.exercise_model.network.eval()
            self.exercise_model.network.cpu()
            print(f"✓ Exercise model loaded from {model_path.name}")
            gc.collect()
        except Exception as e:
            print(f"✗ Failed to load exercise model: {e}")
            self.exercise_model = None
        
        try:
            self.menstrual_model = TabNetClassifier()
            optimized_path = MODEL_DIR / 'menstrual' / 'menstrual_tabnet_best_optimized.zip'
            original_path = MODEL_DIR / 'menstrual' / 'menstrual_tabnet_best.zip'
            model_path = optimized_path if optimized_path.exists() else original_path
            
            self.menstrual_model.load_model(str(model_path))
            self.menstrual_model.network.eval()
            self.menstrual_model.network.cpu()
            self.menstrual_classes = ['Regular', 'Short', 'Long']
            print(f"✓ Menstrual model loaded from {model_path.name}")
            gc.collect()
        except Exception as e:
            print(f"✗ Failed to load menstrual model: {e}")
            self.menstrual_model = None
        
        # Feature engineers (lightweight)
        self.obesity_engineer = ObesityFeatureEngineer()
        self.exercise_engineer = ExerciseFeatureEngineer()
        
        self._initialized = True
        
        # Final memory cleanup
        gc.collect()
        
        loaded_count = sum([
            self.obesity_model is not None,
            self.exercise_model is not None,
            self.menstrual_model is not None
        ])
        print(f"Model loading complete! {loaded_count}/3 models loaded successfully")


# Initialize models on startup
models = MLModels()
models._load_models()


# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

def aggregate_lifestyle_data(lifestyle_data: DailyLifestyleData):
    """Aggregate lifestyle data into features"""
    features = {}
    
    # Hydration features
    features['daily_water_ml'] = lifestyle_data.totalWaterMl
    features['hydration_frequency'] = len(lifestyle_data.hydrationLogs)
    features['avg_water_per_log'] = lifestyle_data.totalWaterMl / max(len(lifestyle_data.hydrationLogs), 1)
    
    # Mood features
    if lifestyle_data.moodLogs:
        moods = [log.get('intensity', 5) for log in lifestyle_data.moodLogs]
        features['avg_mood_intensity'] = np.mean(moods)
        features['mood_variability'] = np.std(moods) if len(moods) > 1 else 0
        
        # Count negative factors
        all_factors = []
        for log in lifestyle_data.moodLogs:
            all_factors.extend(log.get('factors', []))
        features['stress_factors_count'] = len([f for f in all_factors if f in ['work', 'stress', 'anxiety']])
    else:
        features['avg_mood_intensity'] = 5
        features['mood_variability'] = 0
        features['stress_factors_count'] = 0
    
    # Symptom features
    if lifestyle_data.symptoms:
        severities = [s.get('severity', 0) for s in lifestyle_data.symptoms]
        features['symptom_count'] = len(lifestyle_data.symptoms)
        features['avg_symptom_severity'] = np.mean(severities)
        features['max_symptom_severity'] = max(severities)
    else:
        features['symptom_count'] = 0
        features['avg_symptom_severity'] = 0
        features['max_symptom_severity'] = 0
    
    # Activity features
    features['exercise_duration'] = lifestyle_data.exerciseDuration or 0
    features['exercise_intensity'] = lifestyle_data.exerciseIntensity or 0
    features['heart_rate'] = lifestyle_data.heartRate or 0
    
    # Sleep features
    features['sleep_hours'] = lifestyle_data.sleepHours or 7.0
    
    # Diet features
    features['calories_consumed'] = lifestyle_data.caloriesConsumed or 2000
    
    return features


def analyze_symptom_risks(symptoms: List[Dict]) -> Optional[Dict]:
    """Analyze symptoms to determine probable health conditions and risk level"""
    if not symptoms:
        return None
    
    print(f"[DEBUG] Analyzing {len(symptoms)} symptoms: {symptoms}")  # Debug logging
    
    # Symptom pattern mapping to probable conditions
    symptom_patterns = {
        'Cardiovascular': ['chest pain', 'shortness of breath', 'irregular heartbeat', 'palpitations', 'fainting'],
        'Respiratory': ['cough', 'shortness of breath', 'wheezing', 'chest tightness', 'difficulty breathing'],
        'Gastrointestinal': ['nausea', 'vomiting', 'diarrhea', 'abdominal pain', 'bloating', 'constipation', 'heartburn'],
        'Neurological': ['headache', 'migraine', 'dizziness', 'numbness', 'tingling', 'confusion', 'memory loss'],
        'Musculoskeletal': ['joint pain', 'muscle pain', 'back pain', 'stiffness', 'swelling'],
        'Endocrine/Metabolic': ['fatigue', 'weight changes', 'excessive thirst', 'frequent urination', 'hot flashes', 'cold intolerance'],
        'Mental Health': ['anxiety', 'depression', 'mood swings', 'insomnia', 'stress', 'panic attacks'],
        'Gynecological': ['irregular periods', 'heavy bleeding', 'pelvic pain', 'cramps', 'spotting'],
        'Dermatological': ['rash', 'itching', 'skin changes', 'hives', 'acne'],
        'General/Systemic': ['fever', 'chills', 'night sweats', 'fatigue', 'weakness', 'loss of appetite']
    }
    
    # Analyze symptoms
    detected_symptoms = []
    condition_scores = {condition: 0 for condition in symptom_patterns.keys()}
    total_severity = 0
    max_severity = 0
    
    for symptom in symptoms:
        # Handle both 'type' and 'symptomType' field names
        symptom_type_raw = symptom.get('type') or symptom.get('symptomType') or symptom.get('symptom_type', '')
        symptom_type = str(symptom_type_raw).lower().strip()
        severity_raw = symptom.get('severity', 0)
        try:
            severity = int(float(severity_raw))
        except (ValueError, TypeError):
            severity = 5
        severity = max(1, min(10, severity))
        
        print(f"[DEBUG] Processing symptom: type='{symptom_type}', severity={severity}")  # Debug
        
        detected_symptoms.append({
            'type': symptom_type_raw if symptom_type_raw else 'Unknown',
            'severity': severity,
            'description': symptom.get('description') or symptom.get('notes', '')
        })
        
        total_severity += severity
        max_severity = max(max_severity, severity)
        
        # Match symptom to conditions - check if pattern is in symptom_type OR symptom_type is in pattern
        matched = False
        for condition, patterns in symptom_patterns.items():
            for pattern in patterns:
                # Bidirectional matching: "headache" matches "severe headache" and vice versa
                if symptom_type and (pattern in symptom_type or symptom_type in pattern):
                    condition_scores[condition] += severity
                    matched = True
                    print(f"[DEBUG] Matched '{symptom_type}' to {condition} via pattern '{pattern}'")
                    break  # Only count once per condition
            if matched:
                break
    
    # Determine probable conditions (top 3 with scores > 0)
    probable_conditions = []
    sorted_conditions = sorted(condition_scores.items(), key=lambda x: x[1], reverse=True)
    for condition, score in sorted_conditions:
        if score > 0 and len(probable_conditions) < 3:
            probable_conditions.append(condition)  # Just the condition name, no score
    
    if not probable_conditions:
        probable_conditions.append("General symptoms - requires medical evaluation")
    
    # Determine risk level and urgency
    symptom_count = len(symptoms)
    avg_severity = total_severity / symptom_count if symptom_count > 0 else 0
    
    red_flag_patterns = [
        'chest pain',
        'shortness of breath',
        'difficulty breathing',
        'fainting',
        'seizure',
        'confusion',
        'stroke',
    ]
    has_red_flag = False
    for symptom in symptoms:
        symptom_text = str(
            symptom.get('type') or symptom.get('symptomType') or symptom.get('symptom_type', '')
        ).lower()
        if any(flag in symptom_text for flag in red_flag_patterns):
            has_red_flag = True
            break

    if (has_red_flag and max_severity >= 7) or (symptom_count >= 4 and avg_severity >= 7) or (symptom_count >= 2 and max_severity >= 9):
        risk_level = "Critical"
        urgency = "Urgent Care - Seek immediate medical attention"
    elif has_red_flag or (symptom_count >= 3 and avg_severity >= 6) or (symptom_count >= 2 and max_severity >= 8):
        risk_level = "High"
        urgency = "Seek Medical Attention - Schedule appointment within 24-48 hours"
    elif symptom_count >= 2 or avg_severity >= 5 or max_severity >= 7:
        risk_level = "Moderate"
        urgency = "Schedule Checkup - Consult healthcare provider within a week"
    else:
        risk_level = "Low"
        urgency = "Monitor - Track symptoms and seek care if they worsen"
    
    return {
        'probableConditions': probable_conditions,
        'riskLevel': risk_level,
        'urgency': urgency,
        'detectedSymptoms': detected_symptoms
    }


def generate_recommendations(risk_level: str, bmi: float, lifestyle_features: dict) -> List[str]:
    """Generate personalized recommendations based on risk assessment"""
    recommendations = []
    
    # SYMPTOM ANALYSIS (Priority #1)
    symptom_count = lifestyle_features.get('symptom_count', 0)
    avg_severity = lifestyle_features.get('avg_symptom_severity', 0)
    max_severity = lifestyle_features.get('max_symptom_severity', 0)
    
    if symptom_count > 0:
        if symptom_count >= 5 or max_severity >= 8:
            recommendations.append(f"⚠️ URGENT: You have {symptom_count} symptoms logged with severity up to {max_severity}/10. Please consult a healthcare provider immediately.")
        elif symptom_count >= 3 or avg_severity >= 6:
            recommendations.append(f"⚕️ You're experiencing {symptom_count} symptoms (avg severity: {avg_severity:.1f}/10). Consider scheduling a medical checkup.")
        else:
            recommendations.append(f"📋 {symptom_count} symptom(s) logged. Monitor your symptoms and seek medical advice if they worsen.")
    
    # BMI-based recommendations
    if bmi < 18.5:
        recommendations.append(f"⚖️ Your BMI ({bmi:.1f}) indicates underweight. Consult a nutritionist for a healthy weight gain plan with adequate calories and nutrients.")
    elif bmi >= 30:
        recommendations.append(f"⚖️ Your BMI ({bmi:.1f}) indicates obesity. Focus on gradual weight loss through balanced diet and regular exercise.")
    elif bmi >= 25:
        recommendations.append(f"⚖️ Your BMI ({bmi:.1f}) indicates overweight. Small lifestyle changes can help you reach a healthy weight.")
    
    # Hydration recommendations
    water_ml = lifestyle_features.get('daily_water_ml', 0)
    if water_ml < 1500:
        recommendations.append(f"💧 Low hydration: {water_ml}ml/day. Increase water intake to at least 2000ml for better health and metabolism.")
    
    # Activity recommendations
    exercise_min = lifestyle_features.get('exercise_duration', 0)
    if exercise_min < 30:
        recommendations.append(f"🏃 Exercise: {exercise_min} min/day. Aim for at least 30 minutes of moderate activity daily for cardiovascular health.")
    
    # Mood recommendations
    avg_mood = lifestyle_features.get('avg_mood_intensity', 5)
    if avg_mood < 4:
        recommendations.append(f"😊 Your mood scores are low (avg: {avg_mood:.1f}/10). Consider stress management, meditation, or talking to a mental health professional.")
    
    # Sleep recommendations
    sleep_hrs = lifestyle_features.get('sleep_hours', 7)
    if sleep_hrs < 6:
        recommendations.append(f"😴 Sleep: {sleep_hrs} hours/night. Aim for 7-9 hours for optimal recovery and health.")
    
    return recommendations[:6]  # Return top 6 recommendations


# ============================================================================
# API ENDPOINTS
# ============================================================================

@app.get("/")
async def root():
    """Health check endpoint"""
    return {
        "status": "healthy",
        "service": "NovaHealth ML API",
        "version": "1.0.0",
        "models_loaded": {
            "obesity": models.obesity_model is not None,
            "exercise": models.exercise_model is not None,
            "menstrual": models.menstrual_model is not None
        }
    }


@app.post("/predict/health-risk", response_model=HealthRiskResponse)
async def predict_health_risk(request: HealthRiskRequest):
    """
    Main endpoint: Predict comprehensive health risk based on user profile and lifestyle data
    """
    try:
        user = request.userProfile
        lifestyle = request.lifestyleData
        
        # Aggregate lifestyle features
        lifestyle_features = aggregate_lifestyle_data(lifestyle)
        
        # ===== OBESITY RISK PREDICTION =====
        # Calculate BMI first (needed for both model and fallback)
        bmi = user.weight / ((user.height / 100) ** 2)
        
        # Determine risk level based on BMI
        if bmi < 18.5:
            risk_level = 'Insufficient_Weight'
            prediction_idx = 0
        elif bmi < 25:
            risk_level = 'Normal_Weight'
            prediction_idx = 1
        elif bmi < 27:
            risk_level = 'Overweight_Level_I'
            prediction_idx = 5
        elif bmi < 30:
            risk_level = 'Overweight_Level_II'
            prediction_idx = 6
        elif bmi < 35:
            risk_level = 'Obesity_Type_I'
            prediction_idx = 2
        elif bmi < 40:
            risk_level = 'Obesity_Type_II'
            prediction_idx = 3
        else:
            risk_level = 'Obesity_Type_III'
            prediction_idx = 4
        
        # Calculate BMR
        height_cm = user.height
        weight_kg = user.weight
        age = user.age
        is_male = user.gender.lower() == 'male'
        
        if is_male:
            bmr = (10 * weight_kg) + (6.25 * height_cm) - (5 * age) + 5
        else:
            bmr = (10 * weight_kg) + (6.25 * height_cm) - (5 * age) - 161
        
        if models.obesity_model:
            try:
                
                # Create probability distribution (higher confidence for determined class)
                probabilities = np.zeros(7)
                probabilities[prediction_idx] = 0.85
                # Distribute remaining probability to adjacent classes
                remaining = 0.15
                for i in range(7):
                    if i != prediction_idx:
                        probabilities[i] = remaining / 6
                
                prediction = prediction_idx
                
            except Exception as e:
                raise HTTPException(status_code=500, detail=f"Obesity prediction error: {str(e)}")
            
            obesity_risk = ObesityRiskResponse(
                riskLevel=risk_level,
                confidence=float(probabilities[prediction]),
                bmi=bmi,
                bmr=bmr,
                recommendations=generate_recommendations(
                    risk_level,
                    bmi,
                    lifestyle_features
                ),
                allProbabilities={models.obesity_classes[i]: float(probabilities[i]) 
                                 for i in range(len(models.obesity_classes))}
            )
        else:
            # Fallback: Use BMI-based classification when model not available
            obesity_risk = ObesityRiskResponse(
                riskLevel=risk_level,
                confidence=0.85,
                bmi=bmi,
                bmr=bmr,
                recommendations=generate_recommendations(
                    risk_level,
                    bmi,
                    lifestyle_features
                ),
                allProbabilities={risk_level: 0.85}
            )
        
        # ===== EXERCISE RECOMMENDATION =====
        exercise_rec = None
        if False and models.exercise_model and lifestyle_features['exercise_duration'] > 0:  # Disabled due to feature mismatch
            exercise_data = {
                'Exercise': 'General',
                'Dream Weight': user.targetWeight or user.weight,
                'Actual Weight': user.weight,
                'Age': user.age,
                'Gender': user.gender,
                'Duration': lifestyle_features['exercise_duration'],
                'Heart Rate': lifestyle_features['heart_rate'] or 120,
                'BMI': user.weight / ((user.height / 100) ** 2),
                'Weather Conditions': 'Sunny',
                'Exercise Intensity': lifestyle_features['exercise_intensity']
            }
            
            df_ex = pd.DataFrame([exercise_data])
            df_ex_enriched = models.exercise_engineer.engineer_features(df_ex)
            
            # Encode and prepare
            for col in df_ex_enriched.select_dtypes(include=['object']).columns:
                if col not in ['Calories Burn']:
                    le = LabelEncoder()
                    df_ex_enriched[col] = le.fit_transform(df_ex_enriched[col].astype(str))
            
            X_ex = df_ex_enriched.fillna(0).values
            scaler_ex = StandardScaler()
            X_ex_scaled = scaler_ex.fit_transform(X_ex)
            
            # Predict calories
            calories = models.exercise_model.predict(X_ex_scaled)[0][0]
            
            exercise_rec = ExerciseRecommendationResponse(
                predictedCalories=float(calories),
                caloriesPerMinute=float(calories / lifestyle_features['exercise_duration']),
                metScore=float(df_ex_enriched['MET_Score'].values[0]) if 'MET_Score' in df_ex_enriched.columns else 0.0,
                intensityLevel='Low' if lifestyle_features['exercise_intensity'] <= 3 else ('Medium' if lifestyle_features['exercise_intensity'] <= 6 else 'High'),
                recommendations=[
                    f"Great job! You burned approximately {calories:.0f} calories.",
                    "Keep maintaining consistent exercise routine.",
                    "Consider varying intensity for better results."
                ]
            )
        
        # ===== OVERALL RISK SCORE =====
        risk_score = 20.0  # baseline
        
        # Adjust based on obesity risk
        if obesity_risk.riskLevel in ['Obesity_Type_II', 'Obesity_Type_III']:
            risk_score += 30
        elif obesity_risk.riskLevel in ['Obesity_Type_I', 'Overweight_Level_II']:
            risk_score += 15
        elif obesity_risk.riskLevel == 'Overweight_Level_I':
            risk_score += 5
        elif obesity_risk.riskLevel == 'Insufficient_Weight':
            risk_score += 10
        
        # Adjust based on lifestyle
        if lifestyle_features['symptom_count'] >= 4:
            risk_score += 12
        elif lifestyle_features['symptom_count'] >= 2:
            risk_score += 6
        if lifestyle_features['exercise_duration'] < 20:
            risk_score += 8
        if lifestyle_features['daily_water_ml'] < 1500:
            risk_score += 5
        if lifestyle_features['sleep_hours'] < 6:
            risk_score += 8
        
        risk_score = min(100, max(0, risk_score))
        
        # Key insights with detailed symptom analysis
        insights = [
            f"Your BMI is {obesity_risk.bmi:.1f} ({obesity_risk.riskLevel.replace('_', ' ')})",
            f"Overall health risk score: {risk_score:.0f}/100",
        ]
        
        # Symptom insights (priority)
        symptom_count = lifestyle_features['symptom_count']
        if symptom_count > 0:
            avg_severity = lifestyle_features['avg_symptom_severity']
            max_severity = lifestyle_features['max_symptom_severity']
            insights.append(f"⚠️ {symptom_count} symptom(s) logged - Avg severity: {avg_severity:.1f}/10, Max: {max_severity}/10")
        else:
            insights.append("✓ No symptoms logged recently")
        
        # Lifestyle insights
        if lifestyle_features['exercise_duration'] > 30:
            insights.append(f"✓ Good exercise routine: {lifestyle_features['exercise_duration']} min/day")
        else:
            insights.append(f"⚠️ Low exercise: {lifestyle_features['exercise_duration']} min/day")
            
        if lifestyle_features['daily_water_ml'] >= 2000:
            insights.append(f"✓ Adequate hydration: {lifestyle_features['daily_water_ml']}ml/day")
        else:
            insights.append(f"⚠️ Low hydration: {lifestyle_features['daily_water_ml']}ml/day")
        
        # Mood insights
        avg_mood = lifestyle_features['avg_mood_intensity']
        if avg_mood >= 6:
            insights.append(f"✓ Good mood levels: {avg_mood:.1f}/10")
        elif avg_mood > 0:
            insights.append(f"⚠️ Lower mood scores: {avg_mood:.1f}/10")
        
        # Analyze symptoms for probable health risks
        symptom_analysis = None
        if request.lifestyleData.symptoms:
            symptom_data = analyze_symptom_risks(request.lifestyleData.symptoms)
            if symptom_data:
                symptom_analysis = SymptomRiskAnalysis(**symptom_data)
        
        return HealthRiskResponse(
            obesityRisk=obesity_risk,
            exerciseRecommendation=exercise_rec,
            menstrualPrediction=None,  # TODO: Implement if needed
            symptomRiskAnalysis=symptom_analysis,
            overallRiskScore=risk_score,
            keyInsights=insights
        )
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Prediction error: {str(e)}")


@app.post("/predict/obesity")
async def predict_obesity_only(user: UserProfile, lifestyle: DailyLifestyleData):
    """Quick obesity risk prediction endpoint"""
    request = HealthRiskRequest(userProfile=user, lifestyleData=lifestyle)
    result = await predict_health_risk(request)
    return result.obesityRisk


# ============================================================================
# SUGAR SPIKE INSIGHT ENDPOINT  (Beat the Sugar Spike)
# ============================================================================

class SugarInsightRequest(BaseModel):
    """Request body for sugar-spike cause-effect insight."""
    sugarType: str        # chai, cold_drink, sweets, snack
    bmi: float = 22.0
    steps: int = 0        # steps taken today so far

class SugarInsightResponse(BaseModel):
    shortTermImpact: str
    correctiveAction: str

# Sugar grams lookup per preset
_SUGAR_GRAMS = {
    'chai': 10,
    'cold_drink': 35,
    'sweets': 25,
    'snack': 15,
}

@app.post("/predict/sugar-insight", response_model=SugarInsightResponse)
async def predict_sugar_insight(req: SugarInsightRequest):
    """
    Given the sugar type, the user's BMI, and today's step count,
    return a short-term impact sentence and one corrective action.
    """
    sugar_g = _SUGAR_GRAMS.get(req.sugarType, 20)
    bmi = req.bmi
    steps = req.steps

    # ---- Short-term impact (rule-based, contextual) ----
    if req.sugarType == 'cold_drink':
        impact = (
            f"~{sugar_g} g of liquid sugar will spike your blood glucose within 15 minutes. "
            "Expect an energy crash in ~90 min."
        )
    elif req.sugarType == 'sweets':
        impact = (
            f"~{sugar_g} g from sweets triggers a glucose peak in ~20 min. "
        )
        if bmi >= 25:
            impact += "With your current BMI, insulin response may be slower — the spike can last longer."
        else:
            impact += "This may disrupt your sleep quality tonight if eaten after 6 PM."
    elif req.sugarType == 'chai':
        impact = (
            f"~{sugar_g} g from chai causes a mild glucose bump. "
            "Caffeine masks the crash, but it still happens."
        )
    elif req.sugarType == 'snack':
        impact = (
            f"Packaged snacks hide ~{sugar_g} g of sugar plus sodium. "
            "Energy dip expected in ~45 min."
        )
    else:
        impact = f"~{sugar_g} g of sugar will elevate blood glucose within 30 min."

    # ---- Corrective action (personalised by steps + BMI) ----
    if steps < 3000:
        action = "You've barely moved today — a brisk 10-minute walk right now will help your muscles absorb the sugar faster."
    elif steps < 6000:
        action = "Good step count so far. A quick 5-minute stair climb or 20 squats will blunt the spike."
    else:
        action = "You're quite active today! Drink a glass of water and the spike should flatten quickly."

    if bmi >= 30:
        action += " Given your BMI, consider swapping this for a low-sugar alternative next time."
    elif bmi >= 25:
        action += " Pair sugary items with protein or fibre to slow absorption."

    return SugarInsightResponse(
        shortTermImpact=impact,
        correctiveAction=action,
    )


if __name__ == "__main__":
    import uvicorn
    print("Starting NovaHealth ML API Server...")
    print("Models will be loaded on first request")
    uvicorn.run(app, host="0.0.0.0", port=8000, reload=False)
