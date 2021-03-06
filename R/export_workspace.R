#' Create a workspace or a multi-processing
#'
#' Functions to create a 'JDemetra+' workspace (\code{new_workspace()})
#' add a multi-processing to it (\code{new_multiprocessing()}).
#'
#' @param workspace a workspace object
#' @param name character name of the new multiprocessing
#'
#' @return \code{new_workspace()} returns an object of class \code{workspace} and
#' \code{new_multiprocessing()} returns an object of class \code{multiprocessing}.
#'
#' @seealso \code{\link{load_workspace}}, \code{\link{save_workspace}},
#' \code{\link{add_sa_item}}
#'
#' @examples
#' # Create and export a empty 'JDemetra+' workspace
#' wk <- new_workspace()
#' mp <- new_multiprocessing(wk, "sa1")
#'
#'
#' @name new_workspace
#' @rdname new_workspace
#' @export
new_workspace <- function() {
  dictionary = .jnull("jdr/spec/ts/Utility$Dictionary")
  wk <- .jcall("ec/tstoolkit/jdr/ws/Workspace",
               "Lec/tstoolkit/jdr/ws/Workspace;",
               "create", dictionary)
  wk <- new("workspace", wk)
  return(wk)
}
#' @name new_workspace
#' @rdname new_workspace
#' @export
new_multiprocessing <- function(workspace, name) {
  mp <- .jcall(workspace, "Lec/tstoolkit/jdr/ws/MultiProcessing;", "newMultiProcessing", name)
  mp <- new("multiprocessing", mp)
  return(invisible(mp))
}



#' Save a workspace
#'
#' Functions save a \code{workspace} object into a 'JDemetra+'' workspace.
#'
#' @param workspace a workspace object to export
#' @param file the path to the export 'JDemetra+' workspace (.xml file).
#' By default a dialog box opens.
#'
#' @seealso \code{\link{load_workspace}}
#'
#' @examples \donttest{
#' dir <- tempdir()
#' # Create and export a empty 'JDemetra+' workspace
#' wk <- new_workspace()
#' new_multiprocessing(wk, "sa1")
#' save_workspace(wk, file.path(dir, "workspace.xml"))
#'}
#'
#' @return A boolean indicating whether the export has suceed.
#' @export
save_workspace <- function(workspace, file) {
  if (missing(file) || is.null(file)) {
    if (Sys.info()[['sysname']] == "Windows") {
      file <- utils::choose.files(default = "demetra_m.xml",
                                  caption = "Select a workspace for the output",
                                  filters = c("JDemetra+ workspace (.xml)", "*.xml"))
    }else{
      file <- NULL # base::file.choose()
    }
    if (length(file) == 0)
      stop("You have to choose a file !")
  }
  if (length(grep("\\.xml$",file)) == 0)
    stop("The file must be a .xml !")

  full_file_name <- normalizePath(file, winslash = "/", mustWork = FALSE)
  folder_wk_name <- sub(".xml$","", full_file_name)
  workspace_name <- basename(folder_wk_name)


  result <- .jcall(workspace, "Z", "save", full_file_name)
  # To change the name of the workspace
  wk_txt <- readLines(full_file_name)
  wk_txt <- sub(folder_wk_name, workspace_name, wk_txt)
  writeLines(wk_txt, full_file_name)

  invisible(result)
}


#' Add a seasonally adjust model to a multi-processing
#'
#' Function to add a new seasonally adjust object (class \code{"SA"} or \code{"jSA"}) in a \code{workspace} object.
#'
#' @param workspace the workspace to add the seasonally adjust model.
#' @param multiprocessing the name or index of the multiprocessing to add the seasonally adjust model.
#' @param sa_obj the seasonally adjust object to export.
#' @param name the name of the seasonally adjust model in the multiprocessing.
#' By default the name of the \code{sa_obj} is used.
#'
#' @seealso \code{\link{load_workspace}}, \code{\link{save_workspace}}
#'
#' @examples\donttest{
#' dir <- tempdir()
#' spec_x13 <- x13_spec(spec = "RSA5c", easter.enabled = FALSE)
#' sa_x13 <- x13(ipi_c_eu[, "FR"], spec = spec_x13)
#' spec_ts <- tramoseats_spec(spec = "RSA5")
#' sa_ts <- jtramoseats(ipi_c_eu[, "FR"], spec = spec_ts)
#'
#' wk <- new_workspace()
#' new_multiprocessing(wk, "sa1")
#' add_sa_item(wk, "sa1", sa_x13, "X13")
#' add_sa_item(wk, "sa1", sa_ts, "TramoSeats")
#'
#' save_workspace(wk, file.path(dir, "workspace.xml"))
#' }
#'
#' @export
add_sa_item <- function(workspace, multiprocessing, sa_obj, name){
  if (is.character(multiprocessing)) {
    nb_mp_objects <- count(workspace)
    mp_objects <- lapply(seq_len(nb_mp_objects),
                         function(i) {
                           get_object(workspace, i)
                         })
    mp_names <- sapply(mp_objects, get_name)
    multiprocessing <- match(multiprocessing, mp_names)
    if (is.na(multiprocessing))
      stop("The multiprocessing ",multiprocessing," doesn't exist !")
  }
  if (!is.numeric(multiprocessing))
    stop("The parameter multiprocessing must be a character or a numeric")

  if (missing(name))
    name <- deparse(substitute(sa_obj))

  sa_obj <- complete_dictionary(workspace, sa_obj)
  jspec <- get_jspec(sa_obj)
  y <- get_ts(sa_obj)

  if (!is.character(name) || length(name) != 1)
    stop("The name of the SA element to add is mispecified")

  mp_obj <- get_object(workspace, multiprocessing)
  .jcall(mp_obj, "V", "add", name, ts_r2jd(y), jspec)
}

complete_dictionary <- function(workspace, sa_obj){
  UseMethod("complete_dictionary", sa_obj)
}

complete_dictionary.SA <- function(workspace, sa_obj){
  userdef <- sa_obj$regarima$specification$regression$userdef
  ud_var <- userdef$variables
  if (is.null(ud_var) || !userdef$specification["variables"] || is.na(ud_var$series))
    return(sa_obj)

  context_dictionary <- .jcall(workspace,"Lec/tstoolkit/algorithm/ProcessingContext;", "getContext")
  ts_variable_managers <- context_dictionary$getTsVariableManagers()
  ts_variables <- .jnew("ec/tstoolkit/timeseries/regression/TsVariables")
  jd_r_variables <- ts_variable_managers$get("r")
  if (is.null(jd_r_variables)) {
    ts_variable_managers$set("r",
                             .jnew("ec/tstoolkit/timeseries/regression/TsVariables"))
    jd_r_variables <- ts_variable_managers$get("r")
  }
  jd_var_names <- jd_r_variables$getNames()

  model_var_names <- rownames(ud_var$description)

  if (is.mts(ud_var$series)) {
    for (i in seq_along(model_var_names)) {
      name <- model_var_names[i]
      dictionary_var <- jd_r_variables$get(name)
      tsvar <- .jnew("ec/tstoolkit/timeseries/regression/TsVariable",
                     name, ts_r2jd(ud_var$series[, i]))
      if (is.null(dictionary_var)) {
        jd_r_variables$set(name, tsvar)
      } else {
        if (!dictionary_var$getTsData()$equals(tsvar$getTsData())) {
          same_prefix <- grep(paste0("^", name), jd_r_variables$getNames(), value = TRUE)
          same_data <- sapply(same_prefix, function(x) {
            jd_r_variables$get(x)$getTsData()$equals(tsvar$getTsData())
          })
          if (any(same_data)) {
            # a name fix the same prefix  has the same data
            model_new_var_names <- same_prefix[which(same_data)]
          } else {
            model_new_var_names <-  base::make.unique(c(jd_r_variables$getNames(),
                                                    name),
                                                  sep = "_")
          }
          model_var_names[i] <- name <- tail(model_new_var_names, 1)
          tsvar <- .jnew("ec/tstoolkit/timeseries/regression/TsVariable",
                         name, ts_r2jd(ud_var$series[, i]))
          jd_r_variables$set(name, tsvar)
        }
      }
    }
  }else{
    name <- model_var_names
    dictionary_var <- jd_r_variables$get(name)
    tsvar <- .jnew("ec/tstoolkit/timeseries/regression/TsVariable",
                   name, ts_r2jd(ud_var$series))
    if (is.null(dictionary_var)) {
      jd_r_variables$set(name, tsvar)
    } else {
      if (!dictionary_var$getTsData()$equals(tsvar$getTsData())) {
        same_prefix <- grep(paste0("^", name), jd_r_variables$getNames(), value = TRUE)
        same_data <- sapply(same_prefix, function(x) {
          jd_r_variables$get(x)$getTsData()$equals(tsvar$getTsData())
        })
        if (any(same_data)) {
          # a name fix the same prefix  has the same data
          model_new_var_names <- same_prefix[which(same_data)]
        } else {
          model_new_var_names <-  base::make.unique(c(jd_r_variables$getNames(),
                                                  name),
                                                sep = "_")
        }

        model_var_names <- name <- tail(model_new_var_names, 1)
        tsvar <- .jnew("ec/tstoolkit/timeseries/regression/TsVariable",
                       name, ts_r2jd(ud_var$series))
        jd_r_variables$set(name, tsvar)
      }
    }
  }
  rownames(sa_obj$regarima$specification$regression$userdef$variables$description) <-
    model_var_names

  return(sa_obj)
}
complete_dictionary.jSA <- function(workspace, sa_obj){
  model_dictionary <- sa_obj$dictionary
  context <- model_dictionary$toContext()
  current_variables <- context$getTsVariableManagers()$get("r")
  if (is.null(current_variables) || current_variables$getCount() == 0)
    return(sa_obj)

  context_dictionary <- .jcall(workspace,"Lec/tstoolkit/algorithm/ProcessingContext;", "getContext")
  ts_variable_managers <- context_dictionary$getTsVariableManagers()
  jd_r_variables <- ts_variable_managers$get("r")
  if (is.null(jd_r_variables)) {
    ts_variable_managers$set("r",
                             .jnew("ec/tstoolkit/timeseries/regression/TsVariables"))
    jd_r_variables <- ts_variable_managers$get("r")
  }
  variables_names <- data.frame(current_names = current_variables$getNames(),
             new_names = current_variables$getNames(),
             stringsAsFactors = FALSE,
             row.names = current_variables$getNames())

  for (i in seq_len(nrow(variables_names))) {
    name <- variables_names[i,1]
    var <- current_variables$get(name)
    dictionary_var <- jd_r_variables$get(name)
    if (is.null(dictionary_var)) {
      jd_r_variables$set(name, var)
    } else {
      if (!dictionary_var$getTsData()$equals(var$getTsData())) {
        same_prefix <- grep(paste0("^", name), jd_r_variables$getNames(), value = TRUE)
        same_data <- sapply(same_prefix, function(x) {
          jd_r_variables$get(x)$getTsData()$equals(var$getTsData())
        })
        if (any(same_data)) {
          # a name fix the same prefix  has the same data
          model_var_names <- same_prefix[which(same_data)]
        } else {
          model_var_names <-  base::make.unique(c(jd_r_variables$getNames(),
                                                  name),
                                                sep = "_")
        }
        current_variables$remove(name)
        name <- tail(model_var_names, 1)
        var$setName(name)
        current_variables$set(name, var)
        if (!any(same_data))
          jd_r_variables$set(name, var)

        variables_names[i,2] <- name
      }
    }
  }

  if (identical(variables_names[,1], variables_names[,2]))
    return(sa_obj) # no name has been change


  core <- sa_obj$spec$getCore()$clone()

  if (.jinstanceof(core, "ec/satoolkit/tramoseats/TramoSeatsSpecification")) {
    core <- .jcast(spec, "ec/satoolkit/tramoseats/TramoSeatsSpecification")
    spec <- .jnew("jdr/spec/tramoseats/TramoSeatsSpec",core)
  }else{
    if (.jinstanceof(core, "ec/satoolkit/x13/X13Specification")) {
      core <- .jcast(core, "ec/satoolkit/x13/X13Specification")
      spec <- .jnew("jdr/spec/x13/X13Spec", core)
    } else{
      spec = sa_obj$spec
    }
  }
  jregression <- spec$getRegression()
  jtd <- jregression$getCalendar()$getTradingDays()
  user_td <- jtd$getUserVariables()
  n_userdefined_var <- .jcall(jregression,"I","getUserDefinedVariablesCount")

  if (n_userdefined_var > 0) {
    ud_vars <- lapply(seq_len(n_userdefined_var), function(i){
      .jcall(jregression,
             "Ljdr/spec/ts/Utility$UserDefinedVariable;",
             "getUserDefinedVariable",
             as.integer(i - 1))
    })
    type <- sapply(ud_vars, function(x) x$getComponent())
    coeff <- sapply(ud_vars, function(x) x$getCoefficient())
    var_names <- sapply(ud_vars, function(x) gsub("^r\\.","", x$getName()))
    new_names <- variables_names[var_names, 2]
    jregression$clearUserDefinedVariables()
    for (i in seq_len(seq_len(n_userdefined_var))) {
      .jcall(jregression,"V","addUserDefinedVariable",
             new_names[i], type[i], coeff[i])

    }
  }

  if (length(user_td) > 0) {
    var_names <- gsub("^r\\.","", user_td)
    new_names <- variables_names[var_names, 2]
    .jcall(jtd,"V","setUserVariables", .jarray(paste0("r.",new_names)))
  }

  sa_obj$dictionary <- model_dictionary$fromContext(context)
  sa_obj$spec <- spec

  return(sa_obj)
}
