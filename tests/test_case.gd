class_name TestCase
extends RefCounted

var failures: Array[String] = []

func assert_eq(actual, expected, msg: String = "") -> void:
	if actual != expected:
		failures.append("erwartet %s, bekommen %s %s" % [expected, actual, msg])

func assert_true(value: bool, msg: String = "") -> void:
	if not value:
		failures.append("erwartet true %s" % msg)

func assert_false(value: bool, msg: String = "") -> void:
	if value:
		failures.append("erwartet false %s" % msg)

func assert_almost_eq(a: float, b: float, eps: float = 0.0001, msg: String = "") -> void:
	if absf(a - b) > eps:
		failures.append("erwartet %f ± %f, bekommen %f %s" % [b, eps, a, msg])

func assert_between(v: float, lo: float, hi: float, msg: String = "") -> void:
	if v < lo or v > hi:
		failures.append("erwartet %f..%f, bekommen %f %s" % [lo, hi, v, msg])
