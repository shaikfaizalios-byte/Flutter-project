"""Recalculating a generated answer from its structured solution. Pure.

The expression comes from an AI, so it is never evaluated as code: SymPy's own parser runs Python's
eval. Here text is read with ``ast`` and only numbers, known names, arithmetic and a short list of
functions are turned into SymPy objects. Anything else counts as unreadable, and an unreadable
solution fails: a question that can't be checked is not shown.
"""

import ast
import re
from collections.abc import Callable, Mapping, Sequence
from dataclasses import dataclass
from decimal import ROUND_HALF_UP, Decimal, InvalidOperation
from functools import cache
from typing import Any

MAX_EXPRESSION = 300
MAX_POWER = 64
MAX_NAMES = 30
SAME = 1e-9  # two readings of one exact value
KINDS = ("numeric", "symbolic", "reasoning", "fact_recall")
# Points to compare two formulas at. Comparing values can't hang the way simplifying can.
_POINTS = (1.37, 2.91, 0.53)

_SCIENTIFIC = re.compile(
    r"(-?\d+(?:\.\d+)?)\s*(?:\\times|\u00d7|x|\*)\s*10\s*(?:\^|\*\*)\s*\{?\s*(-?\d+)\s*\}?"
)
_PLAIN = re.compile(r"-?\d+(?:\.\d+)?(?:[eE][-+]?\d+)?")
_FRACTION = re.compile(r"^\s*\$?\s*(-?\d+)\s*/\s*(\d+)")


class UnreadableError(ValueError):
    """Text that isn't an expression this module accepts."""


@cache
def _functions() -> dict[str, Callable[[Any], Any]]:
    import sympy

    return {
        "sqrt": sympy.sqrt,
        "exp": sympy.exp,
        "log": sympy.log,
        "ln": sympy.log,
        "log10": lambda x: sympy.log(x, 10),
        "sin": sympy.sin,
        "cos": sympy.cos,
        "tan": sympy.tan,
        "asin": sympy.asin,
        "acos": sympy.acos,
        "atan": sympy.atan,
        "abs": sympy.Abs,
    }


@cache
def _units() -> dict[str, Any]:
    import sympy
    from sympy.physics import units as u

    return {
        "m": u.meter,
        "cm": u.centimeter,
        "mm": u.millimeter,
        "km": u.kilometer,
        "nm": u.nanometer,
        "s": u.second,
        "ms": u.millisecond,
        "min": u.minute,
        "h": u.hour,
        "kg": u.kilogram,
        "g": u.gram,
        "N": u.newton,
        "J": u.joule,
        "kJ": u.kilo * u.joule,
        "eV": u.electronvolt,
        "W": u.watt,
        "Pa": u.pascal,
        "atm": u.atmosphere,
        "C": u.coulomb,
        "V": u.volt,
        "A": u.ampere,
        "ohm": u.ohm,
        "F": u.farad,
        "T": u.tesla,
        "Hz": u.hertz,
        "K": u.kelvin,
        "mol": u.mole,
        "L": u.liter,
        "deg": sympy.pi / 180,
        "rad": sympy.Integer(1),
    }


def _read(text: str, names: Mapping[str, Any]) -> Any:
    """``text`` as a SymPy value, using only ``names``."""
    import sympy

    source = text.replace("^", "**").strip()
    if not source or len(source) > MAX_EXPRESSION:
        raise UnreadableError(text)
    try:
        tree = ast.parse(source, mode="eval")
    except (SyntaxError, ValueError, MemoryError, RecursionError) as exc:
        raise UnreadableError(text) from exc

    def walk(node: ast.AST) -> Any:
        if isinstance(node, ast.Expression):
            return walk(node.body)
        if isinstance(node, ast.Constant):
            value = node.value
            if isinstance(value, bool) or not isinstance(value, int | float):
                raise UnreadableError(text)
            return sympy.Rational(str(value))
        if isinstance(node, ast.Name):
            if node.id in names:
                return names[node.id]
            if node.id == "pi":
                return sympy.pi
            raise UnreadableError(text)
        if isinstance(node, ast.UnaryOp) and isinstance(node.op, ast.USub | ast.UAdd):
            inner = walk(node.operand)
            return -inner if isinstance(node.op, ast.USub) else inner
        if isinstance(node, ast.BinOp):
            left, right = walk(node.left), walk(node.right)
            if isinstance(node.op, ast.Add):
                return left + right
            if isinstance(node.op, ast.Sub):
                return left - right
            if isinstance(node.op, ast.Mult):
                return left * right
            if isinstance(node.op, ast.Div):
                return left / right
            if isinstance(node.op, ast.Pow):
                if not right.is_number or abs(float(right)) > MAX_POWER:
                    raise UnreadableError(text)
                return left**right
            raise UnreadableError(text)
        if (
            isinstance(node, ast.Call)
            and isinstance(node.func, ast.Name)
            and node.func.id in _functions()
            and len(node.args) == 1
            and not node.keywords
        ):
            return _functions()[node.func.id](walk(node.args[0]))
        raise UnreadableError(text)

    try:
        return walk(tree)
    except (TypeError, ZeroDivisionError, OverflowError, RecursionError) as exc:
        raise UnreadableError(text) from exc


def _unit(text: object) -> Any:
    import sympy

    if text is None or (isinstance(text, str) and not text.strip()):
        return sympy.Integer(1)
    if not isinstance(text, str):
        raise UnreadableError(str(text))
    return _read(text, _units())


def _plain_number(value: Any) -> float:
    """A dimensionless value as a float; anything still carrying a unit is a unit mismatch."""
    import sympy
    from sympy.physics import units as u

    base = [u.meter, u.kilogram, u.second, u.ampere, u.kelvin, u.mole, u.candela]
    reduced = u.convert_to(value, base)
    if reduced.has(u.Quantity) or reduced.free_symbols:
        raise UnreadableError("units don't match")
    number = sympy.N(reduced)
    if not number.is_real or not number.is_finite:
        raise UnreadableError("not a real number")
    return float(number)


def recalculated(structured: Mapping[str, Any]) -> float:
    """The answer the stated values and formula give, in the stated unit. Raises ``UnreadableError``
    when they can't be read or their units don't work out."""
    given = structured.get("given")
    expression = structured.get("expression")
    if not isinstance(given, list) or len(given) > MAX_NAMES or not isinstance(expression, str):
        raise UnreadableError("no working")
    names: dict[str, Any] = {}
    for item in given:
        if not isinstance(item, Mapping) or not isinstance(item.get("name"), str):
            raise UnreadableError("bad value")
        value = item.get("value")
        names[item["name"]] = _read(str(value), {}) * _unit(item.get("unit"))
    return _plain_number(_read(expression, names) / _unit(structured.get("unit")))


def number_in(text: str) -> float | None:
    """The first number an option states, in the forms papers use, or None."""
    fraction = _FRACTION.match(text)
    if fraction and int(fraction[2]) != 0:
        return int(fraction[1]) / int(fraction[2])
    scientific = _SCIENTIFIC.search(text)
    if scientific:
        return float(f"{scientific[1]}e{scientific[2]}")
    plain = _PLAIN.search(text)
    return float(plain[0]) if plain else None


def all_numbers(options: Sequence[str]) -> bool:
    """Every option is a number, so the question has a value to recalculate."""
    return bool(options) and all(number_in(o) is not None for o in options)


def close(a: float, b: float, tolerance: float) -> bool:
    return abs(a - b) <= max(tolerance * max(abs(a), abs(b)), SAME)


def key_holds(value: float, key: str, spec_tolerance: str | None, decimals: int | None) -> bool:
    """The recalculated value gives the stated key, under the stated rounding."""
    try:
        wanted = Decimal(key)
        if decimals is not None:
            places = Decimal(1).scaleb(-decimals)
            rounded = Decimal(repr(value)).quantize(places, rounding=ROUND_HALF_UP)
            return rounded == wanted.quantize(places, rounding=ROUND_HALF_UP)
        allowed = Decimal(spec_tolerance or "0")
    except (InvalidOperation, ValueError):
        return False
    return abs(float(wanted) - value) <= max(float(allowed), SAME * max(abs(value), 1.0))


def same_formula(first: str, second: str, symbols: Sequence[str]) -> bool:
    """Two formulas give the same values at several points."""
    if len(symbols) > MAX_NAMES:
        raise UnreadableError("too many symbols")
    results = []
    for shift, point in enumerate(_POINTS):
        names = {s: _read(str(point + i * 0.31 + shift), {}) for i, s in enumerate(symbols)}
        results.append((_plain_number(_read(first, names)), _plain_number(_read(second, names))))
    return all(close(a, b, SAME) for a, b in results)


@dataclass(frozen=True, slots=True)
class Recheck:
    problem: str | None  # None: nothing against it
    recalculated: bool


def recheck(
    *,
    format_name: str,
    options: Sequence[str],
    answer_index: int | None,
    spec: Mapping[str, Any] | None,
    structured: Mapping[str, Any],
    tolerance: float,
) -> Recheck:
    """Recalculates what can be. A question with a value to calculate must have working that gives
    its key: calling it "reasoning" doesn't avoid that."""
    kind = structured.get("kind")
    if kind not in KINDS:
        return Recheck("kind_unknown", False)
    numeric_format = format_name in ("numeric", "integer")
    one_option = answer_index is not None
    if numeric_format or (one_option and all_numbers(options)):
        kind = "numeric" if kind != "symbolic" or numeric_format else kind
    if kind in ("reasoning", "fact_recall") or not (numeric_format or one_option):
        return Recheck(None, False)
    try:
        if kind == "symbolic":
            return Recheck(_symbolic_problem(options, answer_index, structured), True)
        value = recalculated(structured)
    except UnreadableError:
        return Recheck("unreadable", False)
    if numeric_format:
        decimals = structured.get("decimals")
        places = decimals if type(decimals) is int and 0 <= decimals <= 10 else None
        spec = spec or {}
        held = key_holds(value, str(spec.get("value")), spec.get("tolerance"), places)
        return Recheck(None if held else "recalculated_differs", True)
    numbers = [number_in(o) for o in options]
    matching = [i for i, n in enumerate(numbers) if n is not None and close(n, value, tolerance)]
    return Recheck(None if matching == [answer_index] else "recalculated_differs", True)


def _symbolic_problem(
    options: Sequence[str], answer_index: int | None, structured: Mapping[str, Any]
) -> str | None:
    formulas = structured.get("option_expressions")
    expression = structured.get("expression")
    symbols = structured.get("symbols")
    if (
        not isinstance(formulas, list)
        or len(formulas) != len(options)
        or not isinstance(expression, str)
        or not isinstance(symbols, list)
        or not all(isinstance(s, str) for s in symbols)
    ):
        return "unreadable"
    matching = [
        i
        for i, formula in enumerate(formulas)
        if isinstance(formula, str) and same_formula(expression, formula, symbols)
    ]
    return None if matching == [answer_index] else "recalculated_differs"
