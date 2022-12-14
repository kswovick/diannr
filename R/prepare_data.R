#' Import and Filter DIA-NN data and Calculate MaxLFQ
#'
#' @description Performs 4 separate steps to prepare a DIA-NN output for data
#' analysis. 1 Data is imported as implemented in the diann package. 2 Precursors
#' are filtered. 3 According to protein groups, abundances are calculated using
#' the MaxLFQ algorithm as implemented in the diann package. 4 Data is tidied.
#'
#' @param filepath The file path (or name) or the main report.tsv file generated
#' by DIA-NN. The default uses is the file name given by DIA-NN in your active
#' directory.
#' @param contaminants Strings used to filter out proteins that are common
#' contaminants. The default is only Keratin
#' @param q The q value to use to filter precursor identifications.
#' Default is 0.01
#' @param group.q The q value to use to filter protein groupings.
#' Default is 0.01
#' @param pep.value The value to use to filter out proteins with higher posterior
#' error probabilities. Default is 0.50
#'
#' @return A data frame containing protein information, peptide sequence,
#' precursor normalized intensity, and protein group MaxLFQ
#' @export
#'
#' @importFrom magrittr %>%
#'
prepare_data <- function(
      filepath     = 'report.tsv',
      contaminants = 'Keratin',
      q            = 0.01,
      group.q      = 0.01,
      pep.value    = 0.5
) {

   ## Import the data ------------------------------------------------------------
   message('[1/4] Loading the data ...

          ',
          appendLF = F)

   data_in <- diann::diann_load(filepath)

   ## Filter the data ----------------------------------------------------------
   message('[2/4] Filtering Data ...

          ',
          appendLF = F)

   data_filtered <- data_in %>%
      dplyr::filter(
         Lib.Q.Value         <= q &
            Lib.PG.Q.Value      <= group.q &
            PEP                 <= pep.value &
            !stringr::str_detect(
               First.Protein.Description,
               contaminants
            )
      )

   message('DONE
           ', appendLF = F)

   ## Calculate MaxLFQ -----------------------------------------------------------
   message('[3/4] Calculating MaxLFQ intensities ...

          ', appendLF = F)

   data_maxlfq <- diann::diann_maxlfq(
      data_filtered,
      group.header = 'Protein.Group',
      id.header = 'Precursor.Id',
      quantity.header = 'Precursor.Normalised'
   )

   message('DONE
           ', appendLF = F)

   ## Tidy the data --------------------------------------------------------------
   message('[4/4] Tidying the data ...

          ', appendLF = F)

   data_tidy <- data_maxlfq %>%
      as.data.frame() %>%
      tibble::rownames_to_column(var = 'Protein.Group') %>%
      tibble::as_tibble() %>%
      tidyr::pivot_longer(
         cols      = 2:(ncol(data_maxlfq) + 1),
         names_to  = 'File.Name',
         values_to = 'PG.MaxLFQ'
      ) %>%
      dplyr::mutate(
         Log2.PG.Max.LFQ = log2(PG.MaxLFQ)
      ) %>%
      dplyr::right_join(
         y = data_in %>%
            dplyr::select(
               -c('PG.Quantity':'Genes.MaxLFQ.Unique')
               ),
         by = c(
            'File.Name',
            'Protein.Group'
         )
      ) %>%
      janitor::clean_names() %>%
      dplyr::mutate(
         peak_width = rt_stop - rt_start
      ) %>%
      dplyr::select(
         -c(
            'file_name',
            'protein_ids':'protein_names',
            'q_value':'precursor_quantity',
            'lib_q_value':'lib_pg_q_value',
            'precursor_translated':'quantity_quality',
            'rt_start':'predicted_i_rt',
            'ms1_profile_corr':'predicted_i_im'
         )
      ) %>%
      dplyr::mutate(
         'log2_precursor_normalized' = log2(precursor_normalised),
         .after = precursor_normalised
      ) %>%
      dplyr::rename(
         'pg_maxlfq'            = pg_max_lfq,
         'log2_pg_maxlfq'       = log2_pg_max_lfq,
         'sample'               = run,
         'gene_name'            = genes,
         'peptide'              = stripped_sequence,
         'modified_peptide'     = modified_sequence,
         'precursor'            = precursor_id,
         'charge'               = precursor_charge,
         'precursor_normalized' = precursor_normalised,
         'protein_name'         = first_protein_description
      ) %>%
      dplyr::relocate(
         protein_name,
         .before = modified_peptide
      ) %>%
      dplyr::relocate(
         c(
            pg_maxlfq:log2_pg_maxlfq
         ),
         .after = log2_precursor_normalized
      ) %>%
      dplyr::relocate(
         peak_width,
         .after = charge
      ) %>%
      dplyr::relocate(
         rt,
         .after = peak_width
      ) %>%
      dplyr::relocate(
         sample,
         .before = protein_group
      )

   ### Make the sample names easier to read
   data_tidy$sample <- sub("^[^_]*_([^_]*).*", "\\1", data_tidy$sample)

   message('DONE'
           , appendLF = F)

   return(data_tidy)

}
