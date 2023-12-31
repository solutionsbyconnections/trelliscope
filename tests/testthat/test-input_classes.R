test_that2("RadioInput", {
  expect_error(
    RadioInput$new(list(), "Is it good?", options = c("no", "yes")),
    regexp = "must be a scalar"
  )

  expect_error(
    RadioInput$new("good", list(), options = c("no", "yes")),
    regexp = "must be a scalar"
  )

  expect_error(
    RadioInput$new("good", "Is it good?", options = NULL),
    regexp = "with at least one element"
  )

  obj <- RadioInput$new("good", "Is it good?", options = c("no", "yes"))

  expect_equal(
    obj$as_list(),
    list(options = I(c("no", "yes")), type = "radio", active = TRUE,
      label = "Is it good?", name = "good")
  )
})

test_that2("CheckboxInput", {
  expect_error(
    CheckboxInput$new("good", "Is it good?", options = NULL),
    regexp = "with at least one element"
  )

  obj <- CheckboxInput$new("good", "Is it good?", options = c("no", "yes"))

  expect_equal(
    obj$as_list(),
    list(options = I(c("no", "yes")), type = "checkbox", active = TRUE,
      label = "Is it good?", name = "good")
  )

  expect_equal(
    as.character(obj$as_json(pretty = FALSE)),
    '{"options":["no","yes"],"type":"checkbox","active":true,"label":"Is it good?","name":"good"}'
  )
})

test_that2("SelectInput", {
  expect_error(
    SelectInput$new("good", "Is it good?", options = NULL),
    regexp = "with at least one element"
  )

  obj <- SelectInput$new("good", "Is it good?", options = c("no", "yes"))

  expect_equal(
    obj$as_list(),
    list(options = I(c("no", "yes")), type = "select", active = TRUE,
      label = "Is it good?", name = "good")
  )
})

test_that2("MultiselectInput", {
  expect_error(
    MultiselectInput$new("good", "Is it good?", options = NULL),
    regexp = "with at least one element"
  )

  obj <- MultiselectInput$new("good", "Is it good?", options = c("no", "yes"))

  expect_equal(
    obj$as_list(),
    list(options = I(c("no", "yes")), type = "multiselect", active = TRUE,
      label = "Is it good?", name = "good")
  )
})

test_that2("TextInput", {
  expect_error(
    TextInput$new("opinion", "What do you think?", height = "a"),
    regexp = "must be an integer"
  )

  obj <- TextInput$new("opinion", "What do you think?",
    width = 100, height = 10)

  expect_equal(
    obj$as_list(),
    list(height = 10, type = "text", active = TRUE,
      label = "What do you think?", name = "opinion")
  )
})

test_that2("NumberInput", {
  obj <- NumberInput$new("rank", "What would you rank on a scale of 1 to 10?")

  expect_equal(
    obj$as_list(),
    list(max = NULL, min = NULL, type = "number", active = TRUE,
      label = "What would you rank on a scale of 1 to 10?", name = "rank")
  )
})
