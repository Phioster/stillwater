extends TestCase

func test_runner_reports_passes() -> void:
	assert_eq(1, 1)

func test_assert_between_accepts_bounds() -> void:
	assert_between(0.5, 0.0, 1.0)
