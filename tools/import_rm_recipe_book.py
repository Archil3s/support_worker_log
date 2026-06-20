import json
import re
import sys
import unicodedata
from pathlib import Path

from pypdf import PdfReader


def clean(value: str) -> str:
    value = unicodedata.normalize("NFKC", value)
    value = (
        value.replace("\u00a0", " ")
        .replace("\u2022", "•")
        .replace("\u2044", "/")
    )
    value = re.sub(r"(?<=[A-Za-z])-\s+(?=[a-z])", "", value)
    return re.sub(r"\s+", " ", value).strip()


def recipe_title(text: str, page_number: int) -> str:
    if page_number in (126, 191):
        return "Salted Caramel Glazed Maple Bacon Cake Pops"
    lines = [clean(line) for line in text.splitlines() if clean(line)]
    candidates = []
    execution_seen = False
    for line in lines:
        if line == "THE EXECUTION":
            execution_seen = True
            continue
        if not execution_seen:
            continue
        if line in {
            "BREAKFAST",
            "LUNCH",
            "DINNER",
            "SNACKS",
            "SIDES",
            "DESSERTS",
            "THE EXECUTION",
        }:
            continue
        letters = re.sub(r"[^A-Za-z]", "", line)
        if letters and line.upper() == line and len(line) > 3:
            candidates.append(line)
    if candidates:
        return clean(" ".join(candidates[-2:])).title()
    return f"RM Recipe Page {page_number}"


def section_name(text: str) -> str:
    raise RuntimeError("section_name requires a page number")


def section_for_page(page_number: int) -> str:
    ranges = (
        (10, 39, "Breakfast"),
        (41, 70, "Lunch"),
        (73, 102, "Dinner"),
        (104, 134, "Snacks"),
        (136, 165, "Sides"),
        (167, 197, "Desserts"),
    )
    for start, end, section in ranges:
        if start <= page_number <= end:
            return section
    return "Other"


def ingredient_lines(text: str) -> list[str]:
    preparation = text.split("THE PREPARATION", 1)[1].split("THE EXECUTION", 1)[0]
    lines = [clean(line) for line in preparation.splitlines()]
    ingredients = []
    current = ""
    for line in lines:
        if not line:
            continue
        if line.startswith("•"):
            if current:
                ingredients.append(clean(current))
            current = line.lstrip("• ").strip()
        elif current:
            current = f"{current} {line}"
    if current:
        ingredients.append(clean(current))
    if not ingredients:
        ingredients = [
            line
            for line in lines
            if line
            and line.lower()
            not in {
                "the ingredients",
                "the sauce",
                "the crust",
                "the filling",
                "the toppings",
                "brussels sprouts",
                "cheese sauce",
                "pork rind crust",
            }
        ]
    return ingredients


def nutrition(text: str) -> dict:
    result = {}
    patterns = {
        "calories": r"(\d+(?:\.\d+)?)\s*Calories",
        "proteinGrams": r"(\d+(?:\.\d+)?)g\s*Protein",
        "netCarbsGrams": r"(\d+(?:\.\d+)?)g\s*Net Carbs",
    }
    for key, pattern in patterns.items():
        matches = re.findall(pattern, text, re.I)
        if matches:
            result[key] = float(matches[-1])
    return result


def servings(text: str) -> int:
    patterns = (
        r"makes (?:a total of )?(\d+) (?:total )?servings",
        r"makes (\d+) total",
        r"makes (?:a total of )?(\d+) [^.]*",
    )
    for pattern in patterns:
        match = re.search(pattern, text, re.I)
        if match:
            return max(1, int(match.group(1)))
    return 1


def number(value: str) -> float:
    total = 0.0
    for part in value.strip().split():
        if "/" in part:
            numerator, denominator = part.split("/", 1)
            total += float(numerator) / float(denominator)
        else:
            total += float(part)
    return total


def category_for(name: str) -> str:
    value = name.lower()
    if re.search(r"\b(powder|seasoning|extract|sauce|stock|broth|flour)\b", value):
        return "Pantry"
    if re.search(r"\b(peanut butter|almond butter|nut butter)\b", value):
        return "Pantry"
    if re.search(r"\b(beef|pork|chicken|turkey|bacon|ham|sausage|lamb|duck)\b", value):
        return "Meat"
    if re.search(r"\b(tuna|salmon|shrimp|prawn|fish|seafood)\b", value):
        return "Seafood"
    if re.search(r"\b(eggs?|cheese|cream|butter|yogurt|yoghurt)\b", value):
        return "Eggs and dairy"
    if re.search(r"\b(spinach|broccoli|peppers?|jalapenos?|capsicum|avocado|onion|"
                 r"cauliflower|cucumber|tomato|mushroom|zucchini|courgette|"
                 r"lettuce|cabbage|asparagus|kale|beans|radish)\b", value):
        return "Produce"
    return "Pantry"


def supermarket_name(name: str) -> tuple[str, str | None]:
    value = clean(name)
    replacements = (
        (r"\bHoneyville Almond Flour\b", "Almond Flour"),
        (r"\bAlmond Flour\b", "Ground Almonds"),
        (r"\bGolden Flaxseed Meal\b", "Ground Flaxseed"),
        (r"\bFlaxseed Meal\b", "Ground Flaxseed"),
        (r"\bSwerve Sweetener\b", "Erythritol Sweetener"),
        (r"\bNOW Erythritol\b", "Erythritol Sweetener"),
        (r"\bErythritol, powdered\b", "Erythritol Sweetener"),
        (r"\bLiquid Stevia\b", "Liquid Stevia"),
        (r"\bHeavy Whipping Cream\b", "Cream"),
        (r"\bHeavy Cream\b", "Cream"),
        (r"\bGround Beef\b", "Beef Mince"),
        (r"\bBell Peppers?\b", "Capsicum"),
        (r"\bGreen Peppers?\b", "Green Capsicum"),
        (r"\bRed Peppers?\b", "Red Capsicum"),
        (r"\bCilantro\b", "Coriander"),
        (r"\bZucchini\b", "Courgette"),
        (r"\bShrimp\b", "Prawns"),
        (r"\bShiritaki Noodles\b", "Konjac Noodles"),
        (r"\bRao[’']s Tomato Sauce\b", "No Added Sugar Tomato Pasta Sauce"),
        (r"\bReduced Sugar Ketchup\b", "No Added Sugar Tomato Sauce"),
        (r"\bPB Fit Powder\b", "Natural Peanut Butter"),
        (r"\bMCT Oil\b", "Coconut Oil"),
        (r"\bMaple Syrup\b", "Sugar Free Maple Syrup"),
        (r"\bChicken Boullion\b", "Chicken Stock Cube"),
        (r"\bChicken Bouillon\b", "Chicken Stock Cube"),
        (r"\bKosher Salt\b", "Salt"),
        (r"\bQueso Blanco\b", "Halloumi"),
        (r"\bQueso Fresco\b", "Halloumi"),
        (r"\bPepperjack Cheese\b", "Tasty Cheese"),
    )
    adapted = value
    for pattern, replacement in replacements:
        adapted = re.sub(pattern, replacement, adapted, flags=re.I)
    adapted = clean(adapted)
    if adapted == value:
        return adapted, None
    return adapted, f"{value} changed to {adapted} for NZ supermarkets"


def is_pantry_staple(name: str) -> bool:
    return bool(
        re.search(
            r"\b(salt|pepper|water|ice cubes?|garlic powder|onion powder|"
            r"paprika|cumin|cinnamon|oregano|thyme|italian seasoning|"
            r"chili powder|chilli powder|red pepper flakes|baking powder|"
            r"baking soda|vanilla extract|maple extract|cream of tartar|"
            r"nutmeg|curry powder|ground ginger)\b",
            name,
            re.I,
        )
    )


def structured_ingredient(line: str, recipe_servings: int) -> dict | None:
    value = clean(line).lstrip("• ").strip()
    match = re.match(
        r"^(?P<amount>\d+\s+\d+/\d+|\d+/\d+|\d+(?:\.\d+)?)"
        r"(?:\s*[-–]\s*\d+(?:\.\d+)?)?\s*"
        r"(?P<unit>tablespoons?|teaspoons?|packets?|pounds?|"
        r"medium|large|small|slices?|strips?|stalks?|cloves?|sticks?|"
        r"cups?|tbsp\.?|tsp\.?|cans?|lbs?\.?|oz\.?|kg|ml|g|l)?"
        r"\s*(?P<name>.+)$",
        value,
        re.I,
    )
    if not match:
        return None
    amount = number(match.group("amount"))
    unit = (match.group("unit") or "each").lower().rstrip(".")
    name = clean(match.group("name")).strip(" ,.-")
    name = re.sub(r"\([^)]*\)", "", name)
    name = re.sub(
        r",?\s*\b(de-?seeded|seeded|chopped|finely chopped|roughly chopped|"
        r"diced|sliced|grated|shredded|cubed|melted|softened|divided|"
        r"to taste|for frying|for garnish|for greasing|optional)\b.*",
        "",
        name,
        flags=re.I,
    )
    name = re.sub(
        r"^(chopped|diced|sliced|grated|shredded|freshly chopped)\s+",
        "",
        name,
        flags=re.I,
    )
    name = clean(name)
    if not name or name.lower() in {"of", "or"}:
        return None
    name, adaptation = supermarket_name(name)

    if unit == "kg":
        amount *= 1000
        unit = "g"
    elif unit in {"g", "ml"}:
        pass
    elif unit == "l":
        amount *= 1000
        unit = "ml"
    elif unit in {"oz", "lb", "lbs", "pound", "pounds"}:
        amount *= 28.3495 if unit == "oz" else 453.592
        unit = "g"
    elif unit in {"cup", "cups"}:
        amount *= 240
        unit = "ml"
    elif unit in {"tbsp", "tablespoon", "tablespoons"}:
        amount *= 15
        unit = "ml"
    elif unit in {"tsp", "teaspoon", "teaspoons"}:
        amount *= 5
        unit = "ml"
    elif unit in {"stick", "sticks"}:
        amount *= 113
        unit = "g"
    else:
        unit = "each"

    amount /= max(1, recipe_servings)
    ingredient_id = slug(name)
    result = {
        "id": ingredient_id,
        "name": name,
        "amount": round(amount, 3),
        "unit": unit,
        "category": category_for(name),
        "pantryStaple": is_pantry_staple(name),
    }
    if adaptation:
        result["adaptationNote"] = adaptation
    return result


def structured_ingredients(
    lines: list[str], recipe_servings: int, page_number: int
) -> list[dict]:
    ingredients = [
        ingredient
        for line in lines
        if (ingredient := structured_ingredient(line, recipe_servings))
    ]
    if ingredients or page_number != 116:
        return ingredients
    return [
        {
            "id": "cinnamon_roll_oatmeal",
            "name": "Prepared cinnamon roll oatmeal",
            "amount": 0.25,
            "unit": "each",
            "category": "Pantry",
        }
    ]


def slug(value: str) -> str:
    value = re.sub(r"[^a-z0-9]+", "_", value.lower()).strip("_")
    return value[:60] or "recipe"


def main() -> None:
    if len(sys.argv) != 3:
        raise SystemExit(
            "Usage: import_rm_recipe_book.py INPUT_PDF OUTPUT_JSON"
        )
    source = Path(sys.argv[1])
    output = Path(sys.argv[2])
    reader = PdfReader(source)
    recipes = []
    seen_ids = set()

    for page_number, page in enumerate(reader.pages, start=1):
        text = page.extract_text() or ""
        if "THE PREPARATION" not in text or "THE EXECUTION" not in text:
            continue
        title = recipe_title(text, page_number)
        recipe_id = f"rm200_{slug(title)}"
        if recipe_id in seen_ids:
            recipe_id = f"{recipe_id}_p{page_number}"
        seen_ids.add(recipe_id)
        source_ingredients = ingredient_lines(text)
        recipe_servings = servings(text)
        recipe = {
            "id": recipe_id,
            "name": title,
            "diets": ["keto"],
            "section": section_for_page(page_number),
            "minutes": 0,
            "cookbookId": "rm_200",
            "sourcePage": page_number,
            "servings": recipe_servings,
            "sourceIngredients": source_ingredients,
            "ingredients": structured_ingredients(
                source_ingredients, recipe_servings, page_number
            ),
            "steps": [],
            "supermarketAdapted": True,
        }
        recipe.update(nutrition(text))
        recipes.append(recipe)

    output.write_text(
        json.dumps({"version": 1, "recipes": recipes}, indent=2),
        encoding="utf-8",
    )
    print(f"Imported {len(recipes)} recipes to {output}")


if __name__ == "__main__":
    main()
