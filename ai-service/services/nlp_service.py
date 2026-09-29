import re


def create_response(
    intent,
    status,
    original_text,
    value=None,
    unit=None,
    message=None,
    activity=None,
    input_type="TEXT",
):
    """
    Create a consistent response structure for Dia's AI service.
    """
    response = {
        "intent": intent,
        "value": value,
        "unit": unit,
        "status": status,
        "original_text": original_text,
        "input_type": input_type,
    }

    if message is not None:
        response["message"] = message

    if activity is not None:
        response["activity"] = activity

    return response


def parse_nlp_text(text: str):
    """
    Parse a single health entry from natural-language text.

    Supported intents:
    - LOG_GLUCOSE
    - LOG_INSULIN
    - LOG_MEAL
    - LOG_ACTIVITY
    """

    original_text = text
    text = text.lower().strip()

    # ---------------------------------------------------------
    # Keywords
    # ---------------------------------------------------------

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
        "exercise",
        "exercised",
        "workout",
        "worked out",
        "training",
        "trained",
        "physical activity",

        # Walking / running
        "walk",
        "walked",
        "walking",
        "jog",
        "jogged",
        "jogging",
        "run",
        "ran",
        "running",
        "sprint",
        "sprinting",
        "hiking",
        "hiked",
        "trekking",

        # Cycling
        "cycle",
        "cycled",
        "cycling",
        "bike",
        "biked",
        "biking",
        "bicycle",
        "spinning",

        # Water
        "swim",
        "swam",
        "swimming",
        "aqua aerobics",
        "water aerobics",
        "rowing",
        "kayaking",
        "canoeing",
        "paddleboarding",
        "surfing",

        # Gym / strength
        "weightlifting",
        "weight lifting",
        "weights",
        "strength training",
        "resistance training",
        "bodybuilding",
        "powerlifting",
        "crossfit",
        "calisthenics",
        "circuit training",

        # Strength exercises
        "squat",
        "squats",
        "deadlift",
        "deadlifts",
        "bench press",
        "leg press",
        "shoulder press",
        "overhead press",
        "chest press",
        "lat pulldown",
        "pull-up",
        "pull-ups",
        "pullup",
        "pullups",
        "chin-up",
        "chin-ups",
        "push-up",
        "push-ups",
        "pushup",
        "pushups",
        "lunge",
        "lunges",
        "bicep curl",
        "bicep curls",
        "tricep extension",
        "tricep extensions",
        "hip thrust",
        "hip thrusts",
        "glute bridge",
        "glute bridges",
        "calf raise",
        "calf raises",
        "leg extension",
        "leg extensions",
        "leg curl",
        "leg curls",

        # Core
        "plank",
        "planks",
        "sit-up",
        "sit-ups",
        "situp",
        "situps",
        "crunch",
        "crunches",
        "russian twist",
        "mountain climber",
        "mountain climbers",

        # Cardio
        "cardio",
        "aerobics",
        "aerobic exercise",
        "elliptical",
        "treadmill",
        "stair climber",
        "stairmaster",
        "jump rope",
        "skipping rope",
        "jumping jacks",
        "burpee",
        "burpees",
        "hiit",
        "interval training",

        # Flexibility / mind-body
        "yoga",
        "pilates",
        "reformer pilates",
        "stretching",
        "mobility training",
        "tai chi",
        "qigong",

        # Dance
        "dance",
        "dancing",
        "zumba",
        "ballet",
        "salsa",
        "bachata",
        "tango",
        "hip hop dance",

        # Team sports
        "football",
        "soccer",
        "basketball",
        "volleyball",
        "handball",
        "baseball",
        "softball",
        "rugby",
        "cricket",
        "hockey",
        "field hockey",
        "ice hockey",
        "water polo",

        # Racket sports
        "tennis",
        "table tennis",
        "badminton",
        "squash",
        "racquetball",
        "pickleball",
        "padel",

        # Combat sports
        "boxing",
        "kickboxing",
        "muay thai",
        "karate",
        "judo",
        "taekwondo",
        "jiu-jitsu",
        "jiu jitsu",
        "bjj",
        "wrestling",
        "mma",
        "fencing",

        # Winter sports
        "skiing",
        "snowboarding",
        "ice skating",
        "cross-country skiing",

        # Other
        "golf",
        "climbing",
        "rock climbing",
        "indoor climbing",
        "bouldering",
        "skating",
        "roller skating",
        "rollerblading",
        "skateboarding",
        "horse riding",
        "horseback riding",
        "gymnastics",
        "trampoline",
    ]

    # ---------------------------------------------------------
    # Glucose
    # ---------------------------------------------------------

    if any(keyword in text for keyword in glucose_keywords):
        numbers = re.findall(r"-?\d+(?:\.\d+)?", text)

        if not numbers:
            return create_response(
                intent="LOG_GLUCOSE",
                status="MISSING_VALUE",
                original_text=original_text,
                value=None,
                unit="mg/dL",
                message="Please provide your glucose value.",
            )

        value = float(numbers[0])

        if value <= 0:
            return create_response(
                intent="LOG_GLUCOSE",
                status="INVALID_VALUE",
                original_text=original_text,
                value=value,
                unit="mg/dL",
                message="Glucose value must be greater than zero.",
            )

        return create_response(
            intent="LOG_GLUCOSE",
            status="SUCCESS",
            original_text=original_text,
            value=value,
            unit="mg/dL",
        )

    # ---------------------------------------------------------
    # Insulin
    # ---------------------------------------------------------

    if any(keyword in text for keyword in insulin_keywords):
        numbers = re.findall(r"-?\d+(?:\.\d+)?", text)

        if not numbers:
            return create_response(
                intent="LOG_INSULIN",
                status="MISSING_VALUE",
                original_text=original_text,
                value=None,
                unit="units",
                message="Please provide the insulin amount.",
            )

        value = float(numbers[0])

        if value <= 0:
            return create_response(
                intent="LOG_INSULIN",
                status="INVALID_VALUE",
                original_text=original_text,
                value=value,
                unit="units",
                message="Insulin amount must be greater than zero.",
            )

        return create_response(
            intent="LOG_INSULIN",
            status="SUCCESS",
            original_text=original_text,
            value=value,
            unit="units",
        )

    # ---------------------------------------------------------
    # Meal / carbohydrates
    # ---------------------------------------------------------

    if any(keyword in text for keyword in meal_keywords):
        numbers = re.findall(r"-?\d+(?:\.\d+)?", text)

        if not numbers:
            return create_response(
                intent="LOG_MEAL",
                status="MISSING_VALUE",
                original_text=original_text,
                value=None,
                unit="grams",
                message="Please provide the carbohydrate amount.",
            )

        value = float(numbers[0])

        if value <= 0:
            return create_response(
                intent="LOG_MEAL",
                status="INVALID_VALUE",
                original_text=original_text,
                value=value,
                unit="grams",
                message="Carbohydrate amount must be greater than zero.",
            )

        return create_response(
            intent="LOG_MEAL",
            status="SUCCESS",
            original_text=original_text,
            value=value,
            unit="grams",
        )

    # ---------------------------------------------------------
    # Physical activity
    # ---------------------------------------------------------

    matched_activity = next(
        (
            activity
            for activity in sorted(
                activity_keywords,
                key=len,
                reverse=True,
            )
            if activity in text
        ),
        None,
    )

    if matched_activity:
        numbers = re.findall(r"-?\d+(?:\.\d+)?", text)

        if not numbers:
            return create_response(
                intent="LOG_ACTIVITY",
                status="MISSING_VALUE",
                original_text=original_text,
                value=None,
                unit=None,
                message=(
                    "Please provide the activity duration, "
                    "distance, or repetitions."
                ),
                activity=matched_activity,
            )

        value = float(numbers[0])

        if value <= 0:
            return create_response(
                intent="LOG_ACTIVITY",
                status="INVALID_VALUE",
                original_text=original_text,
                value=value,
                unit=None,
                message="Activity value must be greater than zero.",
                activity=matched_activity,
            )

        # Determine activity unit
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
            "squat",
            "squats",
            "push-up",
            "push-ups",
            "pushup",
            "pushups",
            "pull-up",
            "pull-ups",
            "pullup",
            "pullups",
            "chin-up",
            "chin-ups",
            "lunge",
            "lunges",
            "burpee",
            "burpees",
            "sit-up",
            "sit-ups",
            "situp",
            "situps",
            "crunch",
            "crunches",
        ]:
            unit = "repetitions"

        else:
            unit = "unspecified"

        return create_response(
            intent="LOG_ACTIVITY",
            status="SUCCESS",
            original_text=original_text,
            value=value,
            unit=unit,
            activity=matched_activity,
        )

    # ---------------------------------------------------------
    # Unknown
    # ---------------------------------------------------------

    return create_response(
        intent="UNKNOWN",
        status="UNKNOWN",
        original_text=original_text,
        value=None,
        unit=None,
        message="I could not understand the input.",
    )


# -------------------------------------------------------------
# Multi-intent parsing
# -------------------------------------------------------------

def parse_multiple_entries(text: str):
    """
    Parse multiple health entries from a single user message.

    Example:
    "My glucose is 130 and I took 6 units of insulin"

    Existing parse_nlp_text() behaviour is preserved.
    """

    original_text = text

    parts = re.split(
        r"\s+(?:and|then)\s+|[,;]",
        text,
        flags=re.IGNORECASE,
    )

    results = []

    for part in parts:
        part = part.strip()

        if not part:
            continue

        result = parse_nlp_text(part)

        if result["intent"] != "UNKNOWN":
            results.append(result)

    if not results:
        return {
            "status": "UNKNOWN",
            "input_type": "TEXT",
            "original_text": original_text,
            "results": [],
            "message": "I could not understand the input.",
        }

    return {
        "status": "SUCCESS",
        "input_type": "TEXT",
        "original_text": original_text,
        "results": results,
}
