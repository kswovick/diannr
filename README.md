
<!-- README.md is generated from README.Rmd. Please edit that file -->

# diannr

<!-- badges: start -->
<!-- badges: end -->

The goal of `diannr` is to make data analysis and visualization of
search results from [DIA-NN](https://github.com/vdemichev/diann) more
simple. This package is primarily-aimed towards core facilities to make
excel reports and simple PDF figures they can give to their customers.

This package is heavily inspired by the
[protti](https://github.com/jpquast/protti) and
[diann](https://github.com/vdemichev/diann-rpackage) packages.

## Installation

You can install the development version of diannr from
[GitHub](https://github.com/kswovick) with:

``` r
# install.packages("devtools")
devtools::install_github("kswovick/diannr")
```

## Import and Prepare DIA-NN Data for Analysis

First, we must import the data and prepare it for further downstream
analyses. This steps performs four separate steps including:

1.  Load the data
2.  Filter the data
3.  Perform MaxLFQ
4.  Tidy the data

``` r
library(diannr)
data <- prepare_data(
                     filename = 'report.tsv',
                     contaminants = 'Keratin',
                     q = 0.01,
                     group.q = 0.01,
                     pep.value = 0.5
                     )
```

### Importing Data

In this package, we utilize the main report generated by DIA-NN, usually
‘report.tsv’. This file contains useful information suchs as: protein
annotation, abundance, q-value, and chromatographic data for every
precursor.

### Filtering Data

After the data is loaded, we filter off of several values including:

1.  Precursor Library Q-Value (default is 1%)
2.  Protein Group Library Q-Value (default is 1%)
3.  Posterior Probability Value (default is 50%)

### Performing MaxLFQ

Since we likely removed some low-confidence precursors from protein
groups, we need to recalculate the MaxLFQ values. These values are
normalized protein quantities calculated using that
[MaxLFQ](https://www.mcponline.org/article/S1535-9476(20)33310-7/fulltext)
algorithm. In this package, MaxLFQ is calculated based on protein
grouping; we most frequently perform differential expression experiments
so we are cautious with precursors with amino acid sequences that map to
multiple proteins.

### Tidying Data

Lastly, we remove unwanted columns and use `janitor` to clean each
column name and convert precursor and MaxLFQ intensities to Log2.

## Create Metadata

In order to properly group samples together into conditions, we need to
supply `diannr` with information establishing the relationship between
sample and condition.

This can be done one of two ways:

### Option 1: `create_metadata` Function

We have included a `create_metadata` function that will ask you the
condition of each sample and create a metadata table for you. However,
in order to properly annotate the data you need to know the order of
your samples. The simplest way is to do the following:

``` r
view(dplyr::distinct(data, sample))
```

    #> # A tibble: 6 x 1
    #>   sample
    #>    <dbl>
    #> 1      2
    #> 2      3
    #> 3      4
    #> 4      5
    #> 5      6
    #> 6      1

Now knowing the order of your samples, run `create_meatadata`:

``` r
sample_annotation <- create_metadata(data = data)
```

This will give you a prompt in your console telling you to type the
condition of each sample in the order they appear. According to the
order of your samples above, enter the condition of each sample. It is
important that each condition is separated by a comma and no spaces:

``` r
WT,WT,KO,KO,KO,WT
```

This will result in a data frame that looks like:

    #> # A tibble: 6 x 2
    #>   sample condition
    #>    <dbl> <chr>    
    #> 1      2 WT       
    #> 2      3 WT       
    #> 3      4 KO       
    #> 4      5 KO       
    #> 5      6 KO       
    #> 6      1 WT

### Option 2: Make Your Own Data Frame

Arguably, it might just be easier to make your own data frame with the
metadata information. First, you are going to need to install `tibble`
and create a new tibble. For example:

``` r
#install.packages('tibble')
library(tibble)
sample_annotation <- tibble(
   'sample' = c(1, 2, 3, 4, 5, 6),
   'condition' = c('WT', 'WT', 'WT', 'KO', 'KO', 'KO')
   )

sample_annotation
#> # A tibble: 6 x 2
#>   sample condition
#>    <dbl> <chr>    
#> 1      1 WT       
#> 2      2 WT       
#> 3      3 WT       
#> 4      4 KO       
#> 5      5 KO       
#> 6      6 KO
```

## Combine Metadata with Data

With the metadata in hand, we can now attribute conditions to each
sample in our tidied data set. For this, we have two separate functions,
`annotate_peptide` and `annotate_protein`

### `annotate_peptide`

This function attaches condition information to precursor-level data.

``` r
pep_data <- annotate_peptide(
   data = data,
   sample_annotation = sample_annotation
)
```

### `annotate_protein`

This function is slightly more sophisticated that `annotate_peptide` and
performs several tasks:

1.  Groups all precursors belonging to the same protein group together
2.  Counts the number of total peptides that were quantified in each
    sample for a given protein group
3.  Imputes missing values based upon a down-shifted Gaussian
    distribution similar to the implementation in
    [Perseus](https://www.nature.com/articles/nmeth.3901).

``` r
pg_data <- annotate_protein(
   data = data,
   sample_annotation = sample_annotation
)
```

## Calculate Differential Expression Using a Moderated T-Test

To see what proteins are up- and down-regulated between conditions, we
measure the difference in average Log2 MaxLFQ and a p-value of that
difference through use of a moderated student’s t-test.

``` r
t_test_data <- perform_t_test(
   pg_data = pg_data
)
```

## Create Outputs

After we measure differential expression changes and significance,
`diannr` can create a multitude of files.

### Customer Report

`write_report` makes a .tsv report in your working directory. This is
designed to be formatted according to each Core’s preferences and sent
to customers.

``` r
write_report(pep_data = pep_data,
             pg_data = pg_data,
             filename = 'diannr_report.tsv')
```

The data in the .tsv is formatted as follows:

-   Each row is one protein group
-   Columns contain:
    -   ‘Protein Group’
    -   ‘Gene Name’
    -   ‘Protein Name’
    -   ‘Log2 Expression Change’ for each comparison
    -   ‘p-value’ for each comparison
    -   ‘Average Log2 MaxLFQ’ of each condition
    -   ‘Number of Peptides’ quantified for each sample
    -   ‘Log2MaxLFQ’ for each sample

### QC Plots

`make_qc_plots` makes a multi-page PDF file in your working directory.
This file has figures designed for Core facilities to use for
QC-purposes and to compare samples within one experiment.

``` r
make_qc_plots(pep_data = pep_data,
             pg_data = pg_data,
             filename = 'diannr_QC_plots.pdf',
             peak_shape = T,
             charge_state = T,
             cv = T,
             precursor_coverage = T,
             peptide_coverage = T,
             protein_coverage = T,
             precursor_completeness = T,
             peptide_completeness = T,
             protein_completeness = T,
             precursor_intensity = T,
             protein_intensity = T)
```

The plots generated are as follows:

-   peak_shape: A line plot for each sample depicting the mean peak
    width (minutes) as a function of retention time (minutes).
-   charge_state: Bar plots depicting the percentage of precursor charge
    states for each sample.
-   cv: Box and whisker plots displayed over violin plots depicting the
    distribution of protein-group MaxLFQ between all samples and all
    samples in one condition.
-   precursor_coverage: Bar graphs depicting the number of precursors
    quantified in each sample.
-   peptide_coverage: Bar graphs depicting the number of peptides
    quantified in each sample (one peptide can be composed of multiple
    charge states and/or different modifications).
-   protein_coverage: Bar graphs depicting the number of protein groups
    quantified in each sample.
-   precursor_completeness: Bar graphs depicting the percentage of
    precursors quantified in a given sample out of the total number of
    precursors quantified in the entire experiment.
-   peptide_completeness: Bar graphs depicting the percentage of
    peptides quantified in a given sample out of the total number of
    peptides quantified in the entire experiment.
-   protein_completeness: Bar graphs depicting the percentage of
    peptides quantified in a given sample out of the total number of
    proteins quantified in the entire experiment. This is done before
    imputation.
-   precursor_intensity: Violin plots depicting the distribution of Log2
    normalized precursor intensities of each sample.
-   protein_intensity: Violin plots depicting the distribution of Log2
    protein group MaxLFQ intensities of each sample. Note: this is after
    imputation so seeing a hump at the lower end of the distribution is
    expected.

### Customer Reports

`make_customer_plots` makes a multi-page PDF file in your working
directory. This file has figures designed for Core facilities to send to
customers to give them some basic visualization of their data.

``` r
make_customer_plots(pep_data = pep_data,
                    pg_data = pg_data,
                    t_test_data = t_test_data,
                    filename = 'diannr_customer_plots.pdf',
                    sample_correlation = T,
                    protein_coverage = T,
                    protein_completeness = T,
                    protein_intensity = T,
                    volcano = T,
                    fold_change_cutoff = 1,
                    p_value_cutoff = 0.05
                    )
```

The plots generated are as follows:

-   sample_correlation: A heatmap displaying the spearman rank
    correlation between each sample. It also displays the relationship
    between each sample after hierarchical clustering as a dendrogram.
-   protein_coverage: Bar graphs depicting the number of protein groups
    quantified in each sample.
-   protein_completeness: Bar graphs depicting the percentage of
    peptides quantified in a given sample out of the total number of
    proteins quantified in the entire experiment. This is done before
    imputation.
-   protein_intensity: Violin plots depicting the distribution of Log2
    protein group MaxLFQ intensities of each sample. Note: this is after
    imputation so seeing a hump at the lower end of the distribution is
    expected.
-   volcano: A volcano plot for every comparison is automatically
    generated and printed onto a new page. For a given comparison, this
    displays the log10 p-value of the change in protein expression as a
    function of the difference in log2 MaxLFQ intensities. Each dot
    corresponds to a specific protein quantified in both comparison
    groups. By default, proteins with a fold change \>1 or \<-1 and
    p-value \< 0.05. These values can be changed by using different
    values for `fold_change_cutoff` and `p_value_cutoff`.
