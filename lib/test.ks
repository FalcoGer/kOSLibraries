// Assertion functions for testing.

FUNCTION TEST_ASSERT_TRUE
{
  PARAMETER result.
  PARAMETER msg IS "Expected TRUE, got FALSE".
  
  IF NOT result {
    PRINT msg.
    PRINT lineDelim.
    LOCAL ASSERT_TRUE_FAILURE IS 1 / 0.
  }
}

TEST_ASSERT_TRUE(TRUE, "Self-Test").

FUNCTION TEST_ASSERT_FALSE
{
  PARAMETER result.
  PARAMETER msg IS "Expected FALSE, got TRUE".
  
  IF result {
    PRINT msg.
    PRINT lineDelim.
    LOCAL ASSERT_FALSE_FAILURE IS 1 / 0.
  }
}

TEST_ASSERT_FALSE(FALSE, "Self-Test").

FUNCTION TEST_ASSERT_EQUAL
{
  PARAMETER a, b.
  PARAMETER msg IS "Expected " + a + " = " + b + ", but it is not.".
  IF NOT (a = b)
  {
    PRINT msg.
    PRINT lineDelim.
    LOCAL ASSERT_EQUAL_FAILURE IS 1 / 0.
  }
}

TEST_ASSERT_EQUAL(5, 5, "Self-Test").
TEST_ASSERT_EQUAL(-5, -5, "Self-Test").
TEST_ASSERT_EQUAL("test", "test", "Self-Test").

FUNCTION TEST_ASSERT_APROX
{
  PARAMETER a, b, margin.
  PARAMETER msg IS "Expected " + a + " = " + b + " within +/- " + margin + ", but it is not.".
  IF NOT ((a - margin <= b) AND (a + margin >= b))
  {
    PRINT msg.
    PRINT lineDelim.
    LOCAL ASSERT_EQUAL_FAILURE IS 1 / 0.
  }
}

TEST_ASSERT_APROX(1, 1.7, 1, "Self-Test").
TEST_ASSERT_APROX(-1, -1.7, 1, "Self-Test").
TEST_ASSERT_APROX(10, 17, 10, "Self-Test").
TEST_ASSERT_APROX(1, 2, 1, "Self-Test").
TEST_ASSERT_APROX(1, 0, 1, "Self-Test").
TEST_ASSERT_APROX(10, 20, 10, "Self-Test").
TEST_ASSERT_APROX(0.0004, 0.0005, 0.0001, "Self-Test").
TEST_ASSERT_APROX(0.00045, 0.00055, 0.0001, "Self-Test").
TEST_ASSERT_APROX(0.00045, 0.0005, 0.0001, "Self-Test").

FUNCTION TEST_ASSERT_LESS
{
  PARAMETER a, b.
  PARAMETER msg IS "Expected " + a + " < " + b + ".".
  IF NOT (a < b)
  {
    PRINT msg.
    PRINT lineDelim.
    LOCAL ASSERT_LESS_FAILURE IS 1 / 0.
  }
}

TEST_ASSERT_LESS(-5, 5, "Self-Test").

FUNCTION TEST_ASSERT_MORE
{
  PARAMETER a, b.
  PARAMETER msg IS "Expected " + a + " > " + b + ".".
  IF NOT (a > b)
  {
    PRINT msg.
    PRINT lineDelim.
    LOCAL ASSERT_LESS_FAILURE IS 1 / 0.
  }
}

TEST_ASSERT_MORE(5, -5, "Self-Test").

FUNCTION TEST_ASSERT_LESSOREQUAL
{
  PARAMETER a, b.
  PARAMETER msg IS "Expected " + a + " <= " + b + ".".
  IF NOT (a <= b)
  {
    PRINT msg.
    PRINT lineDelim.
    LOCAL ASSERT_LESSOREQUAL_FAILURE IS 1 / 0.
  }
}

TEST_ASSERT_LESSOREQUAL(-5, 5, "Self-Test").
TEST_ASSERT_LESSOREQUAL(-5, -5, "Self-Test").

FUNCTION TEST_ASSERT_MOREOREQUAL
{
  PARAMETER a, b.
  PARAMETER msg IS "Expected " + a + " >= " + b + ".".
  IF NOT (a >= b)
  {
    PRINT msg.
    PRINT lineDelim.
    LOCAL ASSERT_MOREOREQUAL_FAILURE IS 1 / 0.
  }
}

TEST_ASSERT_MOREOREQUAL(5, 5, "Self-Test").
TEST_ASSERT_MOREOREQUAL(5, -5, "Self-Test").

FUNCTION TEST_ASSERT_NOTEQUAL
{
  PARAMETER a, b.
  PARAMETER msg IS "Expected " + a + " <> " + b + ".".
  IF NOT (a <> b)
  {
    PRINT msg.
    PRINT lineDelim.
    LOCAL ASSERT_NOTEQUAL_FAILURE IS 1 / 0.
  }
}

TEST_ASSERT_NOTEQUAL(5, -5, "Self-Test").
TEST_ASSERT_NOTEQUAL("test1", "test2", "Self-Test").