# analysis
# outcomes = ed, inpat, neuro, ecoe, ct/eeg/mri, cc tot claims, cc sz claims
# predictors = comorbidities, sdoh/adi, demographics, epilepsy dx length

library(tidyverse)
library(gtsummary)
library(data.table)
library(pscl)

path_prefix <- "C:/Users/VHAHOUZHOUR/OneDrive - Department of Veterans Affairs/Documents/Projects/pte_sdoh/"

# coh <- read.csv(file.path(path_prefix, "pte_cohort.csv"))
# dem <- read.csv(file.path(path_prefix, "pte_demographics.csv"))

# basic_dem <- dem %>% 
#   distinct(PERSON_ID, FIRST_DX_DATE, Gender, BirthDateTime) %>%
#   mutate(FIRST_DX_DATE = mdy(sub(" .*", "", FIRST_DX_DATE))) %>%
#   mutate(BirthDateTime = mdy(sub(" .*", "", BirthDateTime)))

# basic_dem$age <- round(as.numeric(difftime(ymd(20230101), basic_dem$BirthDateTime, units="days"))/365.25, digits=2)
# basic_dem$dx_length <- as.numeric(difftime(ymd(20230101), basic_dem$FIRST_DX_DATE, units="days"))

# race <- distinct(dem, PERSON_ID, Race) # sometimes more than one race is listed

# clean_race <- function(races) {
#   # takes in a vector of races, which is typically given from a group_by function
#   # applies algorithm to determine the appropriate new label
  
#   # case: there is a declined to answer and any other value that isn't declined to answer
#   # handled by: removing declined to answer, as there is clearly an answer
#   if("DECLINED TO ANSWER" %in% races && any(races != "DECLINED TO ANSWER")) {
#     races <- races[races != "DECLINED TO ANSWER"]
#   }
  
#   # case: there is an unknown by patient, but there is any other value that isn't unknown by patient
#   # handled by: removing unknown by patient, as there is clearly a known answer (that isn't declined to answer, since it should have been handled above in first step) 
#   if("UNKNOWN BY PATIENT" %in% races && any(races != "UNKNOWN BY PATIENT")) {
#     races <- races[races != "UNKNOWN BY PATIENT"]
#   }
  
#   # case: white not of hisp orig
#   # handled by: we will just consider this to also be "white", since few people have records which add this detail; this can also be found in ethnicity data if desired  
#   if("WHITE NOT OF HISP ORIG" %in% races) {
#     races <- gsub("WHITE NOT OF HISP ORIG", "WHITE", races)
#   }
  
#   # remove possible duplicates
#   races <- unique(races)
  
#   if(length(races) > 1) {
#     races <- c("MIXED")
#   }
  
#   return(races[1])
# }

# tidy_race <- race %>%
#   group_by(PERSON_ID) %>%
#   summarize(Race = clean_race(Race)) %>%
#   mutate(Race = relevel(factor(Race), ref = "WHITE"))

# sdoh
# sdoh <- read.csv(file.path(path_prefix, "pte_sdoh_icd.csv"))
# # unique sdoh codes on file
# sdoh_counts <- sdoh %>%
#   mutate(VisitDateTime = mdy(sub(" .*", "", VisitDateTime))) %>%
#   filter(VisitDateTime < ymd(20230101)) %>%
#   distinct(PERSON_ID, ICD10Code) %>%
#   group_by(PERSON_ID) %>%
#   count() %>%
#   rename(n_sdoh = n)

# # sep sdoh into cats
# icd_cats <- c("T74", "T76", "Z91", "Z04", "Z91", "X93", "X94", "X95", "X99", "Y00", "Y02", "Y08", "Y03", "Y04", "Y07", "Y09", 
#               "Y35", "Y92", "Z69", "Z55", "Z56", "Z59", "Z60", "Z62", "Z63", "Z65")
# icd_cat_desc <- c(rep("Abuse", 5), rep("Violence or Assault", 11), 
#                   rep( "Incarceration and Police Encounter", 3),
#                   "Education and Literacy", "Employment", "Housing and Economic Circumstances", 
#                   "Social Environment", rep("Upbringing and Family", 2), "Psychosocial")
# sdoh_icd_groups <- data.frame(
#   ICD10Cat = icd_cats,
#   CategoryDescription = icd_cat_desc
# )

# # summarize counts of icd large groups and small groups
# sdoh <- sdoh %>%
#   filter(!(str_starts(ICD10Code, "Y36") | str_starts(ICD10Code, "Y37"))) %>%
#   mutate(ICD10Cat = sub("\\..*", "", ICD10Code)) %>%
#   left_join(sdoh_icd_groups, by = "ICD10Cat") %>%
#   distinct(PERSON_ID, CategoryDescription, ICD10Cat)

# sdoh_mat <- sdoh %>%
#   distinct(PERSON_ID, CategoryDescription) %>%
#   mutate(value = TRUE) %>%
#   mutate(CategoryDescription = gsub(" ", "", CategoryDescription)) %>%
#   pivot_wider(names_from = CategoryDescription, values_from = value, values_fill = list(value=FALSE))

# sdoh_mat <- select(basic_dem, PERSON_ID) %>%
#   left_join(sdoh_mat, by = "PERSON_ID")

# sdoh_mat[is.na(sdoh_mat)] <- 0
# sdoh_mat <- sdoh_mat[, -11]

# # adi
# cohort_zip <- fread(file.path(path_prefix, "pte_zip4.csv"))
# zip4_adi <- fread(file.path(path_prefix, "selected_zip4.csv"))
# zip4_adi <- zip4_adi[, ADI_NATRANK := suppressWarnings(as.numeric(ADI_NATRANK))
#                      ][!is.na(ADI_NATRANK)]

# # sometimes rankings are missed because they have letters

# zip5 <- zip4_adi[, .(ZIP_4 = as.integer(substr(as.character(ZIP_4), 1, 5)), ADI_NATRANK)
#                  ][, .(ADI_NATRANK = mean(ADI_NATRANK)), by = ZIP_4]

# zip_adi_final <- rbind(zip4_adi, zip5)
# zip_adi_final <- zip_adi_final[ZIP_4 %in% cohort_zip$Zip4, ]

# pte_adi <- distinct(left_join(cohort_zip, zip_adi_final, by = join_by(Zip4 == ZIP_4)))
# pte_adi <- pte_adi[!is.na(ADI_NATRANK), .(PERSON_ID, ADI_NATRANK)]
# pte_adi <- pte_adi[, .(ADI_NATRANK = mean(ADI_NATRANK)), by = PERSON_ID]

# pte_adi$ADI_NATRANK <- cut(pte_adi$ADI_NATRANK,
#                            breaks = c(0, 25, 50, 75, 100),
#                            labels = c("1st quartile","2nd quartile","3rd quartile","4th quartile"))

# # imaging
# eeg <- read.csv(file.path(path_prefix, "pte_eeg.csv"))
# mri <- read.csv(file.path(path_prefix, "pte_mri.csv"))
# ct <- read.csv(file.path(path_prefix, "pte_ct.csv"))

# # hosp
# ecoe <- read.csv(file.path(path_prefix, "pte_ecoe.csv"))
# pcp <- read.csv(file.path(path_prefix, "pte_pcp.csv"))
# neuro <- read.csv(file.path(path_prefix, "pte_neuro_visits.csv"))
# ed <- read.csv(file.path(path_prefix, "pte_ed_hosp.csv"))

# inpat <- read.csv(file.path(path_prefix, "pte_inpat_hosp.csv")) %>%
#   filter(VISIT_START_DATE != "NULL") %>%
#   mutate(VISIT_START_DATE = mdy(VISIT_START_DATE)) %>%
#   mutate(VISIT_END_DATE = mdy(VISIT_END_DATE)) %>%
#   mutate(FIRST_DX_DATE = mdy_hm(FIRST_DX_DATE)) %>%
#   mutate(VISIT_END_DATE = ifelse(VISIT_END_DATE > ymd(20230101), ymd(20230101), VISIT_END_DATE)) %>%
#   filter(VISIT_START_DATE > FIRST_DX_DATE) %>%
#   arrange(PERSON_ID, VISIT_START_DATE, VISIT_END_DATE) %>%
#   group_by(PERSON_ID) %>%
#   mutate(
#     VISIT_START_DATE = ifelse(
#       row_number() == 1 | VISIT_START_DATE > lag(VISIT_END_DATE, default = first(VISIT_END_DATE)),
#       VISIT_START_DATE, 
#       lag(VISIT_END_DATE, default = first(VISIT_END_DATE) + 1)
#       ),
#     visit_length = as.numeric(VISIT_END_DATE - VISIT_START_DATE + 1)
#   ) %>%
#   filter(VISIT_START_DATE < VISIT_END_DATE) %>%
#   select(PERSON_ID, visit_length, FIRST_DX_DATE) %>%
#   group_by(PERSON_ID) %>%
#   summarize(
#     total_inpat = sum(visit_length),
#     years_active = (as.numeric(difftime(ymd(20230101), first(FIRST_DX_DATE), units = "days")) + 1) / 365.25,
#     days_inpat = total_inpat / years_active
#   ) %>%
#   arrange(desc(days_inpat))

# # days_inpat is inpat per year !

# # claims
# cc <- read.csv(file.path(path_prefix, "pte_cc_claims.csv"))

# # comorbidities
# eci <- read.csv(file.path(path_prefix, "pte_eci.csv"))

# d <- basic_dem %>%
#   left_join(tidy_race, by="PERSON_ID") %>%
#   mutate(had_ct = ifelse(PERSON_ID %in% ct$PERSON_ID, TRUE, FALSE)) %>%
#   mutate(had_eeg = ifelse(PERSON_ID %in% eeg$PERSON_ID, TRUE, FALSE)) %>%
#   mutate(had_mri = ifelse(PERSON_ID %in% mri$PERSON_ID, TRUE, FALSE)) %>%
#   mutate(ecoe = ifelse(PERSON_ID %in% ecoe$PERSON_ID, TRUE, FALSE)) %>%
#   left_join(eci, by="PERSON_ID") %>%
#   left_join(ed, by="PERSON_ID") %>%
#   mutate(ED_PER_YEAR = ifelse(is.na(ED_PER_YEAR), 0, ED_PER_YEAR)) %>%
#   left_join(select(inpat, PERSON_ID, days_inpat), by="PERSON_ID") %>%
#   mutate(days_inpat = ifelse(is.na(days_inpat), 0, days_inpat)) %>%
#   left_join(neuro, by="PERSON_ID") %>%
#   mutate(NEURO_PER_YEAR = ifelse(is.na(NEURO_PER_YEAR), 0, NEURO_PER_YEAR)) %>%
#   left_join(pcp, by = "PERSON_ID") %>%
#   mutate(PCP_PER_YEAR = ifelse(is.na(PCP_PER_YEAR), 0, PCP_PER_YEAR)) %>%
#   left_join(sdoh_counts, by="PERSON_ID") %>%
#   mutate(n_sdoh = ifelse(is.na(n_sdoh), 0, n_sdoh)) %>%
#   left_join(pte_adi, by = "PERSON_ID") %>%
#   select(-c(FIRST_DX_DATE, BirthDateTime)) %>%
#   mutate(dx_length = round(dx_length / 365.25, digits=2)) %>% #change dx len to yrs
#   left_join(cc, by = "PERSON_ID") %>%
#   mutate(N_CLAIMS = ifelse(is.na(N_CLAIMS), 0, N_CLAIMS)) %>%
#   mutate(N_SZ_RELATED = ifelse(is.na(N_SZ_RELATED), 0, N_SZ_RELATED)) %>%
#   left_join(sdoh_mat, by = "PERSON_ID")

# write.csv(d, file.path(path_prefix, "pte_sdoh_complete_data.csv"), row.names=FALSE)
# saving the complete data for future use so this doesn't need to all be run again

d <- read.csv(file.path(path_prefix, "pte_sdoh_complete_data.csv"))

summary <- tbl_summary(
  select(d, -PERSON_ID),
  label = list(
    Gender ~ "Sex",
    age ~ "Age (Years)",
    dx_length ~ "Diagnosis Length (Years)",
    had_ct ~ "Had CT Head Ever",
    ecoe ~ "Visited ECoE Clinic",
    ED_PER_YEAR ~ "Number of ED Visits Per Year*", 
    had_eeg ~ "Had EEG Ever",
    days_inpat ~ "Inpatient Stay Length (Days/Year)*",
    had_mri ~ "Had MRI Brain Ever",
    NEURO_PER_YEAR ~ "Number of Neuro Clinic Visits Per Year*",
    PCP_PER_YEAR ~ "Number of PCP Visits/Year*",
    n_sdoh ~ "Number of Unique SDoH ICDs",
    ADI_NATRANK ~ "ADI Percentile",
    N_CLAIMS ~ "N Community Care Claim Records*",
    N_SZ_RELATED ~ "N Community Care Records w/Seizure Diagnosis*"
  ),
  statistic = list(
    all_continuous() ~ "{mean} ({sd})"
  ),
  digits = all_continuous() ~ 2
)
summary

hist(d$N_CLAIMS, breaks = 50)
hist(d$N_SZ_RELATED, breaks = 50)

# zip for n seizure related
d$N_SZ_RELATED <- ifelse(d$N_SZ_RELATED == 0, 0, ceiling(d$N_SZ_RELATED))

zip_sz_claims <- zeroinfl(N_SZ_RELATED ~ n_sdoh + age + Gender + Race + dx_length + ECI + ADI_NATRANK +
            Psychosocial + UpbringingandFamily + HousingandEconomicCircumstances +
            Employment + EducationandLiteracy + SocialEnvironment + Abuse + ViolenceorAssault +
            IncarcerationandPoliceEncounter, data=d)
summary(zip_sz_claims)

sz_claims_summary <- tbl_regression(
  zip_sz_claims,
  tidy_fun = "tidy_zeroinfl",
  exponentiate = TRUE,
  estimate_fun = ~style_number(.x, digits=3),
  label = list(
    Gender ~ "Sex",
    age ~ "Age (Years)",
    dx_length ~ "Diagnosis Length (Years)",
    ADI_NATRANK ~ "ADI Quartile",
    n_sdoh ~ "Number of Unique SDoH ICDs",
    UpbringingandFamily ~ "Upbringing and Family",
    HousingandEconomicCircumstances ~ "Housing and Economic Circumstances",
    EducationandLiteracy ~ "Education and Literacy",
    SocialEnvironment ~ "Social Environment",
    ViolenceorAssault ~ "Violence or Assault",
    IncarcerationandPoliceEncounter ~ "Incarceration and Police Encounter"
  )
) %>% bold_p()
sz_claims_summary

# poisson for n claims
claims_model <- glm(N_CLAIMS ~ n_sdoh + age + Gender + Race + dx_length + ECI + ADI_NATRANK +
            Psychosocial + UpbringingandFamily + HousingandEconomicCircumstances +
            Employment + EducationandLiteracy + SocialEnvironment + Abuse + ViolenceorAssault +
            IncarcerationandPoliceEncounter, 
            family = poisson(link = "log"),
          data=d)

#summary(visited_neuro_model)

claims_summary <- tbl_regression(
  claims_model,
  estimate_fun = ~style_number(.x, digits=3),
  label = list(
    Gender ~ "Sex",
    age ~ "Age (Years)",
    dx_length ~ "Diagnosis Length (Years)",
    ADI_NATRANK ~ "ADI Quartile",
    n_sdoh ~ "Number of Unique SDoH ICDs",
    UpbringingandFamily ~ "Upbringing and Family",
    HousingandEconomicCircumstances ~ "Housing and Economic Circumstances",
    EducationandLiteracy ~ "Education and Literacy",
    SocialEnvironment ~ "Social Environment",
    ViolenceorAssault ~ "Violence or Assault",
    IncarcerationandPoliceEncounter ~ "Incarceration and Police Encounter"
  ),
  exponentiate = TRUE
) %>% bold_p()
claims_summary

hist(d$NEURO_PER_YEAR, breaks = 50)
mean(d$NEURO_PER_YEAR)
exp(-1.69505)
sum(d$NEURO_PER_YEAR == 0)

visited_neuro_model <- glm(NEURO_PER_YEAR ~ n_sdoh + age + Gender + Race + dx_length + ECI + ADI_NATRANK +
            Psychosocial + UpbringingandFamily + HousingandEconomicCircumstances +
            Employment + EducationandLiteracy + SocialEnvironment + Abuse + ViolenceorAssault +
            IncarcerationandPoliceEncounter, 
            family = poisson(link = "log"),
          data=d)

#summary(visited_neuro_model)

visited_neuro_summary <- tbl_regression(
  visited_neuro_model,
  estimate_fun = ~style_number(.x, digits=3),
  label = list(
    Gender ~ "Sex",
    age ~ "Age (Years)",
    dx_length ~ "Diagnosis Length (Years)",
    ADI_NATRANK ~ "ADI Quartile",
    n_sdoh ~ "Number of Unique SDoH ICDs",
    UpbringingandFamily ~ "Upbringing and Family",
    HousingandEconomicCircumstances ~ "Housing and Economic Circumstances",
    EducationandLiteracy ~ "Education and Literacy",
    SocialEnvironment ~ "Social Environment",
    ViolenceorAssault ~ "Violence or Assault",
    IncarcerationandPoliceEncounter ~ "Incarceration and Police Encounter"
  ),
  exponentiate = TRUE
) %>% bold_p()
visited_neuro_summary

hist(d$PCP_PER_YEAR, breaks = 50)

pcp_model <- glm(PCP_PER_YEAR ~ n_sdoh + age + Gender + Race + dx_length + ECI + ADI_NATRANK +
            Psychosocial + UpbringingandFamily + HousingandEconomicCircumstances +
            Employment + EducationandLiteracy + SocialEnvironment + Abuse + ViolenceorAssault +
            IncarcerationandPoliceEncounter, 
            family = poisson(link = "log"),
          data=d)

#summary(visited_neuro_model)

pcp_summary <- tbl_regression(
  pcp_model,
  estimate_fun = ~style_number(.x, digits=3),
  label = list(
    Gender ~ "Sex",
    age ~ "Age (Years)",
    dx_length ~ "Diagnosis Length (Years)",
    ADI_NATRANK ~ "ADI Quartile",
    n_sdoh ~ "Number of Unique SDoH ICDs",
    UpbringingandFamily ~ "Upbringing and Family",
    HousingandEconomicCircumstances ~ "Housing and Economic Circumstances",
    EducationandLiteracy ~ "Education and Literacy",
    SocialEnvironment ~ "Social Environment",
    ViolenceorAssault ~ "Violence or Assault",
    IncarcerationandPoliceEncounter ~ "Incarceration and Police Encounter"
  ),
  exponentiate = TRUE
) %>% bold_p()
pcp_summary

hist(d$ED_PER_YEAR, breaks = 50)
mean(d$ED_PER_YEAR)
exp(-0.09)
sum(d$ED_PER_YEAR == 0)

hist(d$days_inpat, breaks = 50)

# logistic regression models (ct, eeg, mri, and ecoe)
ecoe_model <- glm(ecoe ~ n_sdoh + age + Gender + Race + dx_length + ECI + ADI_NATRANK +
            Psychosocial + UpbringingandFamily + HousingandEconomicCircumstances +
            Employment + EducationandLiteracy + SocialEnvironment + Abuse + ViolenceorAssault +
            IncarcerationandPoliceEncounter, 
          family = binomial(link="logit"),
          data=d)
#summary(m1)
ecoe_summary <- tbl_regression(
  ecoe_model,
  exponentiate = TRUE,
  estimate_fun = ~style_number(.x, digits=3),
  label = list(
    Gender ~ "Sex",
    age ~ "Age (Years)",
    dx_length ~ "Diagnosis Length (Years)",
    ADI_NATRANK ~ "ADI Quartile",
    n_sdoh ~ "Number of Unique SDoH ICDs",
    UpbringingandFamily ~ "Upbringing and Family",
    HousingandEconomicCircumstances ~ "Housing and Economic Circumstances",
    EducationandLiteracy ~ "Education and Literacy",
    SocialEnvironment ~ "Social Environment",
    ViolenceorAssault ~ "Violence or Assault",
    IncarcerationandPoliceEncounter ~ "Incarceration and Police Encounter"
  )
) %>% bold_p()
ecoe_summary

ct_model <- glm(had_ct ~ n_sdoh + age + Gender + Race + dx_length + ECI + ADI_NATRANK +
            Psychosocial + UpbringingandFamily + HousingandEconomicCircumstances +
            Employment + EducationandLiteracy + SocialEnvironment + Abuse + ViolenceorAssault +
            IncarcerationandPoliceEncounter, 
          family = binomial(link="logit"),
          data=d)
#summary(m1)
ct_summary <- tbl_regression(
  ct_model,
  exponentiate = TRUE,
  estimate_fun = ~style_number(.x, digits=3),
  label = list(
    Gender ~ "Sex",
    age ~ "Age (Years)",
    dx_length ~ "Diagnosis Length (Years)",
    ADI_NATRANK ~ "ADI Quartile",
    n_sdoh ~ "Number of Unique SDoH ICDs",
    UpbringingandFamily ~ "Upbringing and Family",
    HousingandEconomicCircumstances ~ "Housing and Economic Circumstances",
    EducationandLiteracy ~ "Education and Literacy",
    SocialEnvironment ~ "Social Environment",
    ViolenceorAssault ~ "Violence or Assault",
    IncarcerationandPoliceEncounter ~ "Incarceration and Police Encounter"
  )
) %>% bold_p()
ct_summary


## Having Had MRI Brain Ever (Y/N)

mri_model <- glm(had_mri ~ n_sdoh + age + Gender + Race + dx_length + ECI + ADI_NATRANK +
            Psychosocial + UpbringingandFamily + HousingandEconomicCircumstances +
            Employment + EducationandLiteracy + SocialEnvironment + Abuse + ViolenceorAssault +
            IncarcerationandPoliceEncounter, 
          family = binomial(link="logit"),
          data=d)
#summary(m1)
mri_summary <- tbl_regression(
  mri_model,
  exponentiate = TRUE,
  estimate_fun = ~style_number(.x, digits=3),
  label = list(
    Gender ~ "Sex",
    age ~ "Age (Years)",
    dx_length ~ "Diagnosis Length (Years)",
    ADI_NATRANK ~ "ADI Quartile",
    n_sdoh ~ "Number of Unique SDoH ICDs",
    UpbringingandFamily ~ "Upbringing and Family",
    HousingandEconomicCircumstances ~ "Housing and Economic Circumstances",
    EducationandLiteracy ~ "Education and Literacy",
    SocialEnvironment ~ "Social Environment",
    ViolenceorAssault ~ "Violence or Assault",
    IncarcerationandPoliceEncounter ~ "Incarceration and Police Encounter"
  )
) %>% bold_p()
mri_summary


## Having Had EEG Ever (Y/N)

eeg_model <- glm(had_eeg ~ n_sdoh + age + Gender + Race + dx_length + ECI + ADI_NATRANK +
            Psychosocial + UpbringingandFamily + HousingandEconomicCircumstances +
            Employment + EducationandLiteracy + SocialEnvironment + Abuse + ViolenceorAssault +
            IncarcerationandPoliceEncounter, 
          family = binomial(link="logit"),
          data=d)
#summary(m1)
eeg_summary <- tbl_regression(
  eeg_model,
  exponentiate = TRUE,
  estimate_fun = ~style_number(.x, digits=3),
  label = list(
    Gender ~ "Sex",
    age ~ "Age (Years)",
    dx_length ~ "Diagnosis Length (Years)",
    ADI_NATRANK ~ "ADI Quartile",
    n_sdoh ~ "Number of Unique SDoH ICDs",
    UpbringingandFamily ~ "Upbringing and Family",
    HousingandEconomicCircumstances ~ "Housing and Economic Circumstances",
    EducationandLiteracy ~ "Education and Literacy",
    SocialEnvironment ~ "Social Environment",
    ViolenceorAssault ~ "Violence or Assault",
    IncarcerationandPoliceEncounter ~ "Incarceration and Police Encounter"
  )
) %>% bold_p()
eeg_summary

# zip models
d$ED_PER_YEAR <- ifelse(d$ED_PER_YEAR == 0, 0, ceiling(d$ED_PER_YEAR))
hist(d$ED_PER_YEAR, breaks = 50)
zip_ed <- zeroinfl(ED_PER_YEAR ~ n_sdoh + age + Gender + Race + dx_length + ECI + ADI_NATRANK +
            Psychosocial + UpbringingandFamily + HousingandEconomicCircumstances +
            Employment + EducationandLiteracy + SocialEnvironment + Abuse + ViolenceorAssault +
            IncarcerationandPoliceEncounter, data=d)
summary(zip_ed)

ed_summary <- tbl_regression(
  zip_ed,
  tidy_fun = "tidy_zeroinfl",
  exponentiate = TRUE,
  estimate_fun = ~style_number(.x, digits=3),
  label = list(
    Gender ~ "Sex",
    age ~ "Age (Years)",
    dx_length ~ "Diagnosis Length (Years)",
    ADI_NATRANK ~ "ADI Quartile",
    n_sdoh ~ "Number of Unique SDoH ICDs",
    UpbringingandFamily ~ "Upbringing and Family",
    HousingandEconomicCircumstances ~ "Housing and Economic Circumstances",
    EducationandLiteracy ~ "Education and Literacy",
    SocialEnvironment ~ "Social Environment",
    ViolenceorAssault ~ "Violence or Assault",
    IncarcerationandPoliceEncounter ~ "Incarceration and Police Encounter"
  )
) %>% bold_p()
ed_summary

d$days_inpat <- ifelse(d$days_inpat == 0, 0, ceiling(d$days_inpat))

zip_inpat <- zeroinfl(days_inpat ~ n_sdoh + age + Gender + Race + dx_length + ECI + ADI_NATRANK +
            Psychosocial + UpbringingandFamily + HousingandEconomicCircumstances +
            Employment + EducationandLiteracy + SocialEnvironment + Abuse + ViolenceorAssault +
            IncarcerationandPoliceEncounter, data=d)
summary(zip_inpat)

inpat_summary <- tbl_regression(
  zip_inpat,
  tidy_fun = "tidy_zeroinfl",
  exponentiate = TRUE,
  estimate_fun = ~style_number(.x, digits=3),
  label = list(
    Gender ~ "Sex",
    age ~ "Age (Years)",
    dx_length ~ "Diagnosis Length (Years)",
    ADI_NATRANK ~ "ADI Quartile",
    n_sdoh ~ "Number of Unique SDoH ICDs",
    UpbringingandFamily ~ "Upbringing and Family",
    HousingandEconomicCircumstances ~ "Housing and Economic Circumstances",
    EducationandLiteracy ~ "Education and Literacy",
    SocialEnvironment ~ "Social Environment",
    ViolenceorAssault ~ "Violence or Assault",
    IncarcerationandPoliceEncounter ~ "Incarceration and Police Encounter"
  )
) %>% bold_p()
inpat_summary
