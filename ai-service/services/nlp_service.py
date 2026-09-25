import re


def parse_nlp_text(text: str):
    original_text = text
    text = text.lower().strip()

    glucose_keywords = [
        "glucose",
        "blood sugar",
        "blood glucose",
        "sugar level",
    ]

    insulin_keywords = [
        "insulin",
        "units of insulin",
        "unit of insulin",
    ]

    meal_keywords = [
        "carb",
        "carbs",
        "carbohydrate",
        "carbohydrates",
        "grams of carbs",
        "grams of carbohydrate",
    ]

    activity_keywords = [
        # General
        "exercise", "exercised", "workout", "worked out",
        "training", "trained", "physical activity",

        # Walking / running
        "walk", "walked", "walking",
        "jog", "jogged", "jogging",
        "run", "ran", "running",
        "sprint", "sprinting",
        "hiking", "hiked", "trekking",

        # Cycling
        "cycle", "cycled", "cycling",
        "bike", "biked", "biking",
        "bicycle", "spinning",

        # Water
        "swim", "swam", "swimming",
        "aqua aerobics", "water aerobics",
        "rowing", "kayaking", "canoeing",
        "paddleboarding", "surfing",

        # Gym / strength
        "weightlifting", "weight lifting", "weights",
        "strength training", "resistance training",
        "bodybuilding", "powerlifting",
        "crossfit", "calisthenics", "circuit training",

        # Strength exercises
        "squat", "squats",
        "deadlift", "deadlifts",
        "bench press", "leg press",
        "shoulder press", "overhead press",
        "chest press", "lat pulldown",
        "pull-up", "pull-ups", "pullup", "pullups",
        "chin-up", "chin-ups",
        "push-up", "push-ups", "pushup", "pushups",
        "lunge", "lunges",
        "bicep curl", "bicep curls",
        "tricep extension", "tricep extensions",
        "hip thrust", "hip thrusts",
        "glute bridge", "glute bridges",
        "calf raise", "calf raises",
        "leg extension", "leg extensions",
        "leg curl", "leg curls",

        # Core
        "plank", "planks",
        "sit-up", "sit-ups", "situp", "situps",
        "crunch", "crunches",
        "russian twist",
        "mountain climber", "mountain climbers",

        # Cardio
        "cardio", "aerobics", "aerobic exercise",
        "elliptical", "treadmill",
        "stair climber", "stairmaster",
        "jump rope", "skipping rope",
        "jumping jacks",
        "burpee", "burpees",
        "hiit", "interval training",

        # Flexibility / mind-body
        "yoga", "pilates", "reformer pilates",
        "stretching", "mobility training",
        "tai chi", "qigong",

        # Dance
        "dance", "dancing", "zumba",
        "ballet", "salsa", "bachata",
        "tango", "hip hop dance",

        # Team sports
        "football", "soccer", "basketball",
        "volleyball", "handball",
        "baseball", "softball",
        "rugby", "cricket",
        "hockey", "field hockey",
        "ice hockey", "water polo",

        # Racket sports
        "tennis", "table tennis",
        "badminton", "squash",
        "racquetball", "pickleball", "padel",

        # Combat sports
        "boxing", "kickboxing", "muay thai",
        "karate", "judo", "taekwondo",
        "jiu-jitsu", "jiu jitsu", "bjj",
        "wrestling", "mma", "fencing",

        # Winter sports
        "skiing", "snowboarding",
        "ice skating", "cross-country skiing",

        # Other
        "golf", "climbing", "rock climbing",
        "indoor climbing", "bouldering",
        "skating", "roller skating",
        "rollerblading", "skateboarding",
        "horse riding", "horseback riding",
        "gymnastics", "trampoline",
    ]

    # Detect glucose
    if any(keyword in text for keyword in glucose_keywords):
        numbers = re.findall(r"-?\d+(?:\.\d+)?", text)

        if not numbers:
            return {
                "intent": "LOG_GLUCOSE",
                "value": None,
                "unit": "mg/dL",
                "status": "MISSING_VALUE",
                "message": "Please provide your glucose value.",
                "original_text": original_text,
            }

        value = float(numbers[0])

        if value <= 0:
            return {
                "intent": "LOG_GLUCOSE",
                "value": value,
                "unit": "mg/dL",
                "status": "INVALID_VALUE",
                "message": "Glucose value must be greater than zero.",
                "original_text": original_text,
            }

        return {
            "intent": "LOG_GLUCOSE",
            "value": value,
            "unit": "mg/dL",
            "status": "SUCCESS",
            "original_text": original_text,
        }
        # Detect insulin
    if any(keyword in text for keyword in insulin_keywords):
        numbers = re.findall(r"-?\d+(?:\.\d+)?", text)

        if not numbers:
            return {
                "intent": "LOG_INSULIN",
                "value": None,
                "unit": "units",
                "status": "MISSING_VALUE",
                "message": "Please provide the insulin amount.",
                "original_text": original_text,
            }

        value = float(numbers[0])

        if value <= 0:
            return {
                "intent": "LOG_INSULIN",
                "value": value,
                "unit": "units",
                "status": "INVALID_VALUE",
                "message": "Insulin amount must be greater than zero.",
                "original_text": original_text,
            }

        return {
            "intent": "LOG_INSULIN",
            "value": value,
            "unit": "units",
            "status": "SUCCESS",
            "original_text": original_text,
        }
    # Detect meal / carbohydrates
    if any(keyword in text for keyword in meal_keywords):
        numbers = re.findall(r"-?\d+(?:\.\d+)?", text)

        if not numbers:
            return {
                "intent": "LOG_MEAL",
                "value": None,
                "unit": "grams",
                "status": "MISSING_VALUE",
                "message": "Please provide the carbohydrate amount.",
                "original_text": original_text,
            }

        value = float(numbers[0])

        if value <= 0:
            return {
                "intent": "LOG_MEAL",
                "value": value,
                "unit": "grams",
                "status": "INVALID_VALUE",
                "message": "Carbohydrate amount must be greater than zero.",
                "original_text": original_text,
            }

        return {
            "intent": "LOG_MEAL",
            "value": value,
            "unit": "grams",
            "status": "SUCCESS",
            "original_text": original_text,
        }
        # Detect physical activity
    matched_activity = next(
        (
            activity
            for activity in sorted(
                activity_keywords,
                key=len,
                reverse=True
            )
            if activity in text
        ),
        None,
    )

    if matched_activity:
        numbers = re.findall(r"-?\d+(?:\.\d+)?", text)

        if not numbers:
            return {
                "intent": "LOG_ACTIVITY",
                "activity": matched_activity,
                "value": None,
                "unit": None,
                "status": "MISSING_VALUE",
                "message": "Please provide the activity duration, distance, or repetitions.",
                "original_text": original_text,
            }

        value = float(numbers[0])

        if value <= 0:
            return {
                "intent": "LOG_ACTIVITY",
                "activity": matched_activity,
                "value": value,
                "unit": None,
                "status": "INVALID_VALUE",
                "message": "Activity value must be greater than zero.",
                "original_text": original_text,
            }

        if re.search(r"\b(minutes?|mins?|min)\b", text):
            unit = "minutes"

        elif re.search(r"\b(hours?|hrs?|hr)\b", text):
            unit = "hours"

        elif re.search(r"\b(seconds?|secs?|sec)\b", text):
            unit = "seconds"

        elif re.search(r"\b(reps?|repetitions?)\b", text):
            unit = "repetitions"

        elif re.search(r"\b(km|kilometers?|kilometres?)\b", text):
            unit = "km"

        elif re.search(r"\b(miles?|mi)\b", text):
            unit = "miles"

        elif re.search(r"\b(meters?|metres?)\b", text):
            unit = "meters"

        elif matched_activity in [
            "squat", "squats",
            "push-up", "push-ups", "pushup", "pushups",
            "pull-up", "pull-ups", "pullup", "pullups",
            "chin-up", "chin-ups",
            "lunge", "lunges",
            "burpee", "burpees",
            "sit-up", "sit-ups", "situp", "situps",
            "crunch", "crunches",
        ]:
            unit = "repetitions"

        else:
            unit = "unspecified"

        return {
            "intent": "LOG_ACTIVITY",
            "activity": matched_activity,
            "value": value,
            "unit": unit,
            "status": "SUCCESS",
            "original_text": original_text,
        }

    # Dia could not identify the intent
    return {
        "intent": "UNKNOWN",
        "value": None,
        "unit": None,
        "status": "UNKNOWN",
        "message": "I could not understand the input.",
        "original_text": original_text,
    }
