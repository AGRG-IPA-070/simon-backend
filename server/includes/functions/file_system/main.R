#' @title  initilizeDatasetDirectory
#' @description Initialize local directories needed for temporary file saving
#' @param dataset dataset object
#' @return string
initilizeDatasetDirectory <- function(dataset){
    JOB_DIR <- paste0(TEMP_DIR,"/cron_data/",dataset$userID,"/",dataset$queueID,"/",dataset$resampleID)
  
    output_directories  = c('folds', 'models', 'data')
    for (output_dir in output_directories) {
        full_path <- file.path(JOB_DIR, output_dir)
        create_directory(full_path)
    }

    return (JOB_DIR)
}

#' @title  downloadDataset
#' @description Downloads remote tar.gz file extract it and return path
#' @param file_from users_files.file_path => "4/uploads/8d6468cae76877133d404b8ea0c68bcd.tar.gz"
#' @param useCache
#' @return string Path to the local file or FALSE if file doesn't exists
downloadDataset <- function(file_from, useCache = TRUE){
    file_exist <- TRUE

    ## Location to temporary directory where to download files
    temp_directory <- paste0(TEMP_DIR, "/downloads")
    ## Path to the downloaded file
    file_to <- paste0(temp_directory, "/", basename(file_from))
    ## Path to the local extracted file
    file_path_local <- base::gsub(".tar.gz", "", file_to, fixed = TRUE)
    ## in case of duplicated name, on uploading, also check for this one
    file_path_local_dup <- base::gsub(".*_", "", file_path_local)

    if(useCache == TRUE){
        if(file.exists(file_path_local)){
            return (file_path_local)
        }
        if(file.exists(file_path_local_dup)){
            return (file_path_local_dup)
        }
    }

    ## Download requested file from S3 compatible object storage
    exists <- checkFileExists(file_from)
    if(exists == TRUE){
        ## Returns downloaded file path: /tmp/n72qNQFX/downloads/90b1125bfcee4b7e7266a048fd4eb8e3.tar.gz
        file_to <- downloadFile(file_from, file_to)
        Sys.sleep(2)
    }else{
        cat(paste0("===> ERROR: Cannot locate remote file: ",file_from," \r\n"))
        file_exist <- FALSE
    }
    
    if(!file.exists(file_to)){
        cat(paste0("===> ERROR: Cannot locate download gzipped file: ",file_to," \r\n"))
        file_exist <- FALSE
    }else{
        utils::untar(tarfile = file_to, list = FALSE, exdir = temp_directory, verbose = T, tar = which_cmd("tar"))
        
        if(file.exists(file_path_local) || file.exists(file_path_local_dup)){
            cat(paste0("===> INFO: Deleting local tar.gz file since its extracted \r\n"))
            invisible(file.remove(file_to))
        }
    }

    file_path_local <- base::gsub(".tar.gz", "", file_to, fixed = TRUE)

    if(!file.exists(file_path_local)){
        file_path_local_dup <- gsub(".*_", "", file_path_local)
        if(!file.exists(file_path_local_dup)){
            cat(paste0("===> ERROR: Cannot locate extracted file: ",file_path_local," nor ",file_path_local_dup," \r\n"))
            file_exist <- FALSE
        }else{
            file_path_local <- file_path_local_dup
        }
    }

    if(file_exist == FALSE){
        file_path_local <- file_exist
    }
    
    return (file_path_local)
}

#' @title  compressPath
#' @description Compresses file in .tar.gz format and return paths
#' @param filepath_local
#' @return gzipped_path
compressPath <- function(filepath_local){
    ## Rename file to MD5 hash of its filename
    filename <- digest::digest(basename(filepath_local), algo="md5", serialize=F)
    renamed_path = paste0(dirname(filepath_local) , "/" , filename)
    gzipped_path <- paste0(renamed_path, ".tar.gz")

    file.rename(filepath_local, renamed_path)

    try(system(paste0(which_cmd("tar"), " -zcvf " , renamed_path , ".tar.gz -C " , dirname(renamed_path) , " " , basename(renamed_path)), wait = TRUE))

    if(!file.exists(gzipped_path)){
        cat(paste0("===> ERROR: compressPath archive does not exists: ",filepath_local," => ",gzipped_path," \r\n"))
        gzipped_path <- FALSE
    }

    return (list(gzipped_path=gzipped_path, renamed_path=renamed_path))
}