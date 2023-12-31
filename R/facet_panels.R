#' Add a trelliscope facet to a ggplot
#' @param facets A formula to facet the panels on. Similar to
#'   [ggplot2::facet_wrap()]'s `facets``
#' @param scales Should scales be the same (`"same"`, the default),
#'   free (`"free"`), or sliced (`"sliced"`). May provide a single string or
#'   two strings, one for the X and Y axis respectively.
#' @param add_plot_metrics Should metrics about each panel be automatically
#'   calculated? These metrics are based on the context of what is being
#'   plotted, e.g. correlation coefficient if plot is a scatterplot.
#' @param data data used for faceting. Defaults to the first layer data
#' @examples
#' # You can run facet_panels() just like how you would run facet_wrap()
#' library(ggplot2)
#'
#' \dontrun{
#' ggplot(gap, aes(year, life_exp)) +
#'   geom_point() +
#'   facet_panels(vars(country, continent))
#' }
#'
#' # facet_panels can also be a jumping off point into setting up a more
#' # developed trelliscope by passing into `as_panels_df()` to create a nested
#' # trelliscope data frame for additional editing.
#' library(ggplot2)
#' library(dplyr)
#'
#' panel_dat <- (
#'   ggplot(gap, aes(year, life_exp)) +
#'   geom_point() +
#'   facet_panels(vars(country, continent))
#' ) |>
#'   as_panels_df()
#'
#' trell_df <- panel_dat |>
#'   as_trelliscope_df(name = "life expectancy", path = "gapminder") |>
#'   set_default_layout(ncol = 4)
#'
#' \dontrun{
#' view_trelliscope(trell_df)
#' }
#' @param data data used for faceting. Defaults to the main data argument
#'   to [`ggplot2::ggplot()`].
#' @param unfacet Specifies whether to "unfacet" the data such that all of the
#'   data appears in the background of the plot. Options are "none" (default),
#'   "line" or "point". The latter two options will add either a line or point
#'   layer, grouped by the faceting variables, underneath each panel. This is
#'   useful for time series plots for viewing each panel in relation to others.
#' @param unfacet_col The color to use for the "unfacet" lines or points.
#' @param unfacet_alpha The alpha to use for the "unfacet" lines or points.
#' @importFrom ggplot2 facet_wrap waiver
#' @importFrom tidyr nest
#' @export
facet_panels <- function(facets,
  scales = "same", add_plot_metrics = FALSE,
  unfacet = c("none", "line", "point"),
  unfacet_col = "gray", unfacet_alpha = 0.4,
  data = ggplot2::waiver()
) {
  ret <- list(
    facets = facets,
    facet_cols = ggplot2::facet_wrap(facets)$params$facets,
    scales = scales,
    unfacet = match.arg(unfacet),
    unfacet_col = unfacet_col,
    unfacet_alpha = unfacet_alpha,
    add_plot_metrics = add_plot_metrics,
    data = data
  )

  class(ret) <- "facet_panels"
  ret
}

ggplot_add.facet_panels <- function(object, plot, object_name) {
  attr(plot, "trelliscope") <- object[
    c("facets", "facet_cols", "scales", "add_plot_metrics", "data",
      "unfacet", "unfacet_col", "unfacet_alpha")]
  class(plot) <- c("facet_panels", class(plot))
  return(plot)
}

#' Render the panels of a trelliscope display
#' @param x A ggplot object created with [facet_panels()].
#' @param panel_col The name of the column to store the rendered panels in.
#' @param keep_cols An optional vector of extra variable names in `x`
#'   to keep in the data. If specified, its values cannot vary within
#'   each combination of the specified facet variables.
#' @param as_plotly Should the panels be written as plotly objects?
#' @param plotly_args Optional named list of arguments to send to `ggplotly`
#' @param plotly_cfg Optional named list of arguments to send to plotly's
#'   `config`` method.
#' @export
#' @importFrom rlang :=
#' @importFrom dplyr count across
#' @importFrom cli cli_progress_along
as_panels_df <- function(
  x, panel_col = "panel", keep_cols = NULL,
  as_plotly = FALSE, plotly_args = NULL, plotly_cfg = NULL
) {
  assert(inherits(x, "facet_panels"),
    msg = "{.fun as_panels_df} only works with ggplot objects that \\
      use {.fun facet_panels}")
  check_scalar(panel_col, "panel_col")
  check_character(panel_col, "panel_col")
  if (!is.null(keep_cols))
    check_character(keep_cols, "keep_cols")

  if (as_plotly) {
    assert(requireNamespace("plotly", quietly = TRUE),
      "Package 'plotly' is needed for as_plotly = TRUE Please install it.")
  }

  # default name and description
  dnm <- x$labels$title
  if (is.null(dnm))
    dnm <- "ggplot"
  dsc <- paste(c("Faceted by ", attr(x, "trelliscope")$facets), collapse = "")
  x$labels$title <- NULL

  attrs <- attr(x, "trelliscope")

  attrs$as_plotly <- as_plotly
  attrs$plotly_args <- plotly_args
  attrs$plotly_cfg <- plotly_cfg

  # remove special class
  class(x) <- setdiff(class(x), "facet_panels")

  # pp <- ggplot2::ggplot_build(x)

  if (inherits(attrs$data, "waiver")) {
    data <- x$data
    if (inherits(data, "waiver")) {
    # message("using data from the first layer")
      data <- x$layers[[1]]$data # first layer data
    }
  } else {
    # user-supplied
    data <- attrs$data
  }

  assert(!is.null(data),
    "Non-NULL data must be provided either in {.fn ggplot} \
    or in the {.field data} parameter of {.fn facet_panels}")

  # character vector of facet columns
  # TODO need to work with facet_panels(~ disp < 5)
  facet_cols <- unlist(lapply(attrs$facet_cols, rlang::as_name))
  facet_cols <- setdiff(facet_cols, "~")

  data_unfacet <- NULL
  if (attrs$unfacet %in% c("line", "point"))
    data_unfacet <- data

  assert(all(facet_cols %in% names(data)),
    "All facet_panels facet columns must be found in the data being \
    used.")

  assert(!panel_col %in% facet_cols,
    "The variable panel_col='{panel_col}' matches one of the facet \
    columns. Try a different 'panel_col'.")

  if (panel_col %in% names(data))
    wrn("A variable with name matching panel_col='{panel_col}' \\
      exists in the data and is being overwritten")

  keep_cols2 <- c(facet_cols, keep_cols)

  # group by all the facets
  data <- data |>
    dplyr::ungroup() |>
    dplyr::select(dplyr::all_of(keep_cols2)) |>
    dplyr::distinct()
    # # dplyr::mutate(.id = row_number()) |>
    # dplyr::mutate(.id = seq_len(nrow(data))) |>
    # tidyr::nest({{ data_col }} := !dplyr::all_of(keep_cols2)) |>
    # dplyr::ungroup()

  if (!is.null(keep_cols)) {
    nn <- nrow(dplyr::distinct(data,
      dplyr::across(dplyr::all_of(facet_cols))))
    assert(nrow(data) == nn,
      "The values of keep_cols={keep_cols} must be distinct within \
      the values of facet_cols.")
  }

  # get ranges of all data
  scales_info <- upgrade_scales_param(attrs$scales, x$facet)
  scales_info <- add_range_info_to_scales(x, scales_info, attrs$facet_cols)

  # swaps out the data with a subset and removes the facet
  make_plot_obj <- function(dt, pos = -1) {
    if (inherits(attrs$data, "waiver")) {
      data_unfacet <- x$data
      if (inherits(data, "waiver")) {
      # message("using data from the first layer")
        data_unfacet <- x$layers[[1]]$data # first layer data
      }
    } else {
      # user-supplied
      data_unfacet <- attrs$data
    }

    data <- data_unfacet
    for (i in seq_along(facet_cols)) {
      data <- dplyr::filter(data, !!rlang::sym(facet_cols[[i]]) == dt[[i]])
    }
    x$data <- data
    if (attrs$unfacet %in% c("line", "point")) {
      x$layers <- c(geom_unfacet(
        type = attrs$unfacet,
        data = data_unfacet,
        facet_vars = facet_cols,
        color = attrs$unfacet_col,
        alpha = attrs$unfacet_alpha
      ), x$layers)
    }
    x <- add_trelliscope_scales(x, scales_info, show_warnings = (pos == 1))
    if (isTRUE(as_plotly)) {
      x <- do.call(plotly::ggplotly, c(list(p = x), plotly_args))
      if (!is.null(plotly_cfg))
        x <- do.call(plotly::config, c(list(p = x), plotly_cfg))
    }

    x
  }

  by_vals <- lapply(seq_len(nrow(data)), function(i) {
    lapply(as.list(data[i, facet_cols]), function(a) {
      if (is.factor(a))
        a <- as.character(a)
      a
    })
  })

  data[[panel_col]] <- vctrs::new_rcrd(
    fields = list(by = by_vals),
    plot_fn = make_plot_obj,
    by = by,
    d = data,
    as_plotly = as_plotly,
    class = "ggpanel_vec"
  )

  # if (trelliscope) {
  #   new_panel_col <- paste0(panel_col, "_img")
  #   if (!new_panel_col %in% names(data)) {
  #     # TODO: make this get parameters from function
  #     data[[new_panel_col]] <- plot_column(
  #       plot_fn = NULL,
  #       data = panel_col,
  #       by = NULL, # TODO
  #       width = 600, height = 400,
  #       format = "png", force = FALSE)
  #   }
  attr(data, "trelliscope") <- list(
    facet_cols = facet_cols,
    name = dnm,
    description = dsc
  )
  # }

  data
}

#' @export
get_panel_rel_path.ggpanel_vec <- function(x, name, fmt) {
  tmp <- unlist(lapply(vec_data(x)$by, function(x)
    paste(sanitize(x), collapse = "_")))
  file.path("panels", sanitize(name), paste0(tmp, ".", fmt))
}

# only meant to work if x is a single element
#' @export
get_panel.ggpanel_vec <- function(x) {
  plot_fn <- attr(x, "plot_fn")
  plot_fn(unclass(unlist(x)))
}

#' @export
format.ggpanel_vec <- function(x, ...) {
  # vctrs::field(x, "path")
  if (length(x) == 1)
    print(get_panel(x))
  as_plotly <- attr(x, "as_plotly")
  rep(paste0("<", ifelse(as_plotly, "ggplotly", "ggplot"), ">"), length(x))
}

#' @importFrom vctrs vec_ptype_abbr
#' @export
vec_ptype_abbr.ggpanel_vec <- function(
  x, ..., prefix_named = FALSE, suffix_shape = TRUE
) {
  "ggpanels"
}

#' @importFrom pillar pillar_shaft
#' @export
pillar_shaft.ggpanel_vec <- function(x, ...) {
  as_plotly <- attr(x, "as_plotly")
  out <- rep(paste0("<", ifelse(as_plotly, "ggplotly", "ggplot"), ">"), length(x))
  pillar::new_pillar_shaft_simple(out, align = "left")
}

upgrade_scales_param <- function(scales, plot_facet) {
  assert(length(scales) <= 2,
    "Scales must not be longer than length 2")

  assert(length(scales) > 0 && !all(is.na(scales)) && !is.null(scales),
    "Scales must be a character vector of size 1 or 2")

  valid_vals <- c("same", "free", "free_x", "free_y", "sliced",
    "sliced_x", "sliced_y")

  if (length(scales) == 1) {
    scales <- switch(scales,
      "same" = c("same", "same"),
      "free" = c("free", "free"),
      "free_x" = c("free", "same"),
      "free_y" = c("same", "free"),
      "sliced" = c("sliced", "sliced"),
      "sliced_x" = c("sliced", "same"),
      "sliced_y" = c("same", "sliced"),
      assert(FALSE,
        "If scales is of length 1, it may only be one of the following \
        values: {valid_vals}")
    )
  }

  assert(all(scales %in% c("same", "free", "sliced")),
    "A length 2 scales parameter can only be made of 'same', 'free', or \
    'sliced' values")

  # sliced is not allowed for faceted columns
  if (!inherits(plot_facet, "FacetNull")) {
    for (item_val in list(list(1, "x"), list(2, "y"))) {
      if (scales[item_val[[1]]] == "sliced") {
        msg("If a panel is being displayed with 'facet_wrap' or \\
          'facet_grid', the {item_val[[2]]} scale can not be sliced. \\
          Using 'free' instead."
        )
        scales[item_val[[1]]] <- "free"
      }
    }
  }

  list(
    x_info = list(name = "x", scale_type = scales[1]),
    y_info = list(name = "y", scale_type = scales[2]))
}

#' @importFrom utils packageVersion
#' @importFrom ggplot2 ggplot_build
#' @importFrom dplyr vars
add_range_info_to_scales <- function(plot, scales_info, facet_cols) {
  x_scale_type <- scales_info$x_info$scale_type
  y_scale_type <- scales_info$y_info$scale_type

  if (
    any(
      x_scale_type != "free",
      y_scale_type != "free"
    )
  ) {
    # get the ranges from the data
    scale_plot <- plot_clone(plot)

    scales_val <- switch(x_scale_type,
      free = switch(y_scale_type, same = "free_x", "free"),
      sliced = switch(y_scale_type, same = "free_x", "free"),
      same = switch(y_scale_type, same = "fixed", "free_y")
    )

    # if (packageVersion("ggplot2") > "2.2.1") {
    facet_part <- ggplot2::facet_wrap(
      dplyr::vars(facet_cols), scales = scales_val)
    # } else {
    #   facet_part <- ggplot2::facet_wrap(facet_cols, scales = scales_val)
    # }

    if (inherits(scale_plot$facet, "FacetNull")) {
      # add a facet_wrap with scales == free and get limits
      # since can only be same here. build_plot with extra param and take limits
      facet_part$params$facets <- facet_cols

    } else {
      # can only do same (or free)
      # since can only be same here. build_plot with extra param and take limits
      facet_part$params$facets <- append(
        scale_plot$facet$params$rows,
        append(
          scale_plot$facet$params$cols,
          facet_cols
        )
      )
    }
    scale_plot <- scale_plot + facet_part

    scale_plot_built <- ggplot2::ggplot_build(scale_plot)

    calculate_scale_info <- function(scale_info, plot_scales) {
      test_scale <- plot_scales[[1]]
      scale_info$scale <- test_scale

      if (inherits(test_scale, "ScaleDiscrete")) {
        scale_info$data_type <- "discrete"

        if (scale_info$scale_type == "sliced") {
          msg("facet_panels does not know how to handle a 'sliced' \\
            scale for discrete data. Using 'free' type."
          )
          scale_info$scale_type <- "free"
        } else {
          # isn't free, so can take first test_scale and reutrn range values
          scale_info$levels <- test_scale$range$range
        }
      } else {
        # continuous
        scale_info$data_type <- "continuous"

        if (scale_info$scale_type == "same") {
          # test scale is accurate for all panels
          scale_info$range <- test_scale$range$range
        }

        # Behavior for relation="sliced" is similar, except that the length (max - min)
        # of the scales are constrained to remain the same across panels."
        if (scale_info$scale_type == "sliced") {
          range_list <- lapply(plot_scales, function(ps) {
            ps$range$range
          })
          diffs <- unlist(lapply(range_list, diff))

          max_diff <- diffs[which.max(diffs)]

          scale_info$width <- max_diff
        }
      }

      return(scale_info)
    }

    # if (packageVersion("ggplot2") > "2.2.1") {
    scales_info$x_info <- calculate_scale_info(
      scales_info$x_info,
      scale_plot_built$layout$panel_scales_x
    )
    scales_info$y_info <- calculate_scale_info(
      scales_info$y_info,
      scale_plot_built$layout$panel_scales_y
    )
    # } else {
    #   scales_info$x_info <- calculate_scale_info(
    #     scales_info$x_info,
    #     scale_plot_built$layout$panel_scales[[scales_info$x_info$name]]
    #   )
    #   scales_info$y_info <- calculate_scale_info(
    #     scales_info$y_info,
    #     scale_plot_built$layout$panel_scales[[scales_info$y_info$name]]
    #   )
    # }
  }

  scales_info
}

plot_clone <- utils::getFromNamespace("plot_clone", "ggplot2")

add_trelliscope_scales <- function(p, scales_info, ...) {
  p |>
    add_trelliscope_scale(scales_info$x_info$name, scales_info$x_info, ...) |>
    add_trelliscope_scale(scales_info$y_info$name, scales_info$y_info, ...)
}

#' @importFrom rlang eval_tidy
#' @importFrom ggplot2 scale_x_continuous scale_y_continuous scale_x_time
#' scale_y_time scale_x_date scale_y_date scale_x_datetime scale_y_datetime
#' scale_x_discrete scale_y_discrete scale_x_log10 scale_y_log10
# the goal is to add a scale if a scale doesn't already exist.
# if a scale exists, we should NOT overwrite it.
add_trelliscope_scale <- function(
  p, axis_name, scale_info, show_warnings = FALSE
) {
  axis_scales <- p$scales$get_scales(axis_name)
  if (!is.null(axis_scales$limits)) {
    # return if there already is a limit set for this axis
    return(p)
  }

  scale_type <- scale_info$scale_type

  if (
    is.null(p$mapping[[axis_name]])
  ) {
    # this is a possibly calculated axis, leave alone
    if (
      isTRUE(show_warnings) &&
      scale_type != "free" &&
      is.null(p$scales$get_scales(axis_name))
    ) {
      # warn as it isn't a free axis
      msg("Axis: '{axis_name}' is missing a global aesthetic. \\
        Add a custom scale to change default behavior")
    }

    return(p)
  }
  if (scale_type != "free") {
    if (scale_info$data_type == "continuous") {
      # scale_fn <- switch(axis_name,
      #   "x" = scale_x_continuous,
      #   "y" = scale_y_continuous,
      # )
      #
      if (inherits(scale_info$scale, "ScaleContinuousPosition")) {
        if (
          !is.null(scale_info$scale$trans$name) &&
          scale_info$scale$trans$name == "log-10"
        ) {
          scale_fn <- switch(axis_name, "x" = ggplot2::scale_x_log10,
            "y" = ggplot2::scale_y_log10)
        } else {
          scale_fn <- switch(axis_name, "x" = ggplot2::scale_x_continuous,
            "y" = ggplot2::scale_y_continuous)
        }
      } else if (inherits(scale_info$scale, "ScaleContinuousTime")) {
        scale_fn <- switch(axis_name, "x" = ggplot2::scale_x_time,
          "y" = ggplot2::scale_y_time)
      } else if (inherits(scale_info$scale, "ScaleContinuousDate")) {
        scale_fn <- switch(axis_name, "x" = ggplot2::scale_x_date,
          "y" = ggplot2::scale_y_date)
      } else if (inherits(scale_info$scale, "ScaleContinuousDatetime")) {
        scale_fn <- switch(axis_name, "x" = ggplot2::scale_x_datetime,
          "y" = ggplot2::scale_y_datetime)
      }

      if (scale_type == "free") {
        # "Use NA to refer to the existing minimum or maximum."
        p <- p + scale_fn(limits = c(NA, NA))

      } else if (scale_type == "same") {
        # have to make the scale and set the information manually as dates are formatted as numeric
        # p <- p + scale_fn(limits = c(NA, NA))
        scale_item <- scale_fn()
        scale_item$limits <- scale_info$range
        p <- p + scale_item

      } else if (scale_type == "sliced") {
        if (packageVersion("ggplot2") > "2.2.1") {
          dt_range <- rlang::eval_tidy(p$mapping[[axis_name]], data = p$data) |>
            range(na.rm = TRUE)
        } else {
          dt_range <- eval(p$mapping[[axis_name]], envir = p$data) |>
            range(na.rm = TRUE)
        }

        mid_range_val <- mean(dt_range)

        width <- scale_info$width
        limits <- c(mid_range_val - 1 / 2 * width, mid_range_val + 1 / 2 * width)

        if (!isTRUE(all.equal(dt_range, limits))) {
          # this if check is done to avoid silly R floating point rounding errors
          # this situation should only happen twice. one for each axis
          p <- p + scale_fn(limits = limits)
        }
      }
    } else if (scale_info$data_type == "discrete") {
      # data_column <- eval(p$mapping[[axis_name]], envir = p$data)

      scale_fn <- switch(axis_name,
        "x" = scale_x_discrete,
        "y" = scale_y_discrete,
      )

      if (scale_type == "free") {
        # at least have them appear in the same order
        p <- p + scale_fn(limits = scale_info$levels, drop = TRUE)
      } else if (scale_type == "same") {
        p <- p + scale_fn(limits = scale_info$levels, drop = FALSE)
      }
    }
  }

  p
}

# Experimental ggplot2 "unfacet" layer
geom_unfacet <- function(type = c("line", "point"), data, facet_vars,
  color = "gray", alpha = 0.5,
  mapping = NULL, stat = "identity", position = "identity",
  na.rm = FALSE, show.legend = NA, inherit.aes = TRUE, ...
) {
  type <- match.arg(type)
  data$UNFACET <- apply(data[, facet_vars], 1, paste0, collapse = "_")
  data[facet_vars] <- NULL
  mapping <- ggplot2::aes(group = .data$UNFACET)
  params <- list(na.rm = na.rm, ...)
  params$color <- color
  params$alpha <- alpha
  gm <- if (type == "line") {
    ggplot2::GeomLine
  } else {
    ggplot2::GeomPoint
  }
  ggplot2::layer(
    geom = gm, mapping = mapping,
    data = data, stat = stat, position = position,
    show.legend = show.legend, inherit.aes = inherit.aes,
    params = params
  )
}
