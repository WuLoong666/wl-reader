int naturalCompare(String left, String right) {
  final leftTokens = _splitNaturalTokens(left);
  final rightTokens = _splitNaturalTokens(right);
  final length = leftTokens.length < rightTokens.length
      ? leftTokens.length
      : rightTokens.length;

  for (var index = 0; index < length; index += 1) {
    final comparison = _compareNaturalToken(
      leftTokens[index],
      rightTokens[index],
    );
    if (comparison != 0) {
      return comparison;
    }
  }

  return leftTokens.length.compareTo(rightTokens.length);
}

List<_NaturalToken> _splitNaturalTokens(String value) {
  final matches = RegExp(r'\d+|\D+').allMatches(value);
  return matches
      .map((match) => _NaturalToken(match.group(0) ?? ''))
      .toList(growable: false);
}

int _compareNaturalToken(_NaturalToken left, _NaturalToken right) {
  if (left.isNumber && right.isNumber) {
    return _compareNumberToken(left.value, right.value);
  }
  if (left.isNumber != right.isNumber) {
    return left.isNumber ? -1 : 1;
  }

  final comparison = left.normalized.compareTo(right.normalized);
  if (comparison != 0) {
    return comparison;
  }
  return left.value.compareTo(right.value);
}

int _compareNumberToken(String left, String right) {
  final normalizedLeft = _trimLeadingZeros(left);
  final normalizedRight = _trimLeadingZeros(right);

  final lengthComparison =
      normalizedLeft.length.compareTo(normalizedRight.length);
  if (lengthComparison != 0) {
    return lengthComparison;
  }

  final valueComparison = normalizedLeft.compareTo(normalizedRight);
  if (valueComparison != 0) {
    return valueComparison;
  }

  return left.length.compareTo(right.length);
}

String _trimLeadingZeros(String value) {
  final trimmed = value.replaceFirst(RegExp(r'^0+'), '');
  return trimmed.isEmpty ? '0' : trimmed;
}

class _NaturalToken {
  _NaturalToken(this.value)
      : isNumber = RegExp(r'^\d+$').hasMatch(value),
        normalized = value.toLowerCase();

  final String value;
  final bool isNumber;
  final String normalized;
}
