
# This script contains the same code as the R Notebook 
# For detailed explanations and analysis, refer to the notebook


# ----------------------------
# Load libraries
# ----------------------------
library(data.table)
library(dplyr)
library(tidyr)
library(ggplot2)
library(caret)
library(janitor)
library(reshape2)
library(scales)
library(lubridate)
library(isotree)  


# -------------------------------------
# Chunk Function
# -------------------------------------

read_in_chunks <- function(file_path, chunk_size = 10000, ...) {
  # 1. Open the file connection for reading
  con <- file(file_path, open = "r")
  
  # Read the header line (assumes CSV header is in the first line)
  header <- readLines(con, n = 1)
  
  # Prepare an empty list to store chunks
  chunks <- list()
  chunk_index <- 1
  
  repeat {
    # Read the next chunk_size lines
    lines <- readLines(con, n = chunk_size)
    
    # Exit the loop if no more lines are available
    if (length(lines) == 0) break
    
    # Combine header and the chunk's lines to form a valid CSV text
    csv_text <- paste(c(header, lines), collapse = "\n")
    
    # Read the combined text into a data frame
    chunk_df <- read.csv(text = csv_text, header = TRUE, stringsAsFactors = FALSE, ...)
    
    # Store the chunk in the list
    chunks[[chunk_index]] <- chunk_df
    chunk_index <- chunk_index + 1
  }
  
  # Close the connection
  close(con)
  
  return(chunks)
}


# Read category tree.csv
category_tree <- fread("./00_raw_data/category_tree.csv")


# Read events.csv in chunks
events <- read_in_chunks("./00_raw_data/events.csv")

# Read item_properties_part1.1.csv in chunks
item_properties_1 <- read_in_chunks("./00_raw_data/item_properties_part1.1.csv")

# Read item_properties_part2.csv in chunks
item_properties_2 <- read_in_chunks("./00_raw_data/item_properties_part2.csv")


# ------------------------------------------------
# Data Preprocessing for the category tree
# ------------------------------------------------

# Check for duplicates and clean column names
sum(duplicated(category_tree))


# Check for NA's 
colSums(is.na(category_tree) | category_tree == "")

# Replace the NA's in the parentid with the median
median_parentid <- median(category_tree$parentid, na.rm = T)
median_parentid

# Replace missing values in parentid with the median
category_tree <- category_tree %>% 
  mutate(parentid = ifelse(is.na(parentid), median_parentid, parentid))

# Verify changes
sum(is.na(category_tree$parentid))# Replace the NA's in the parentid with the median
median_parentid <- median(category_tree$parentid, na.rm = T)
median_parentid

# Replace missing values in parentid with the median
category_tree <- category_tree %>% 
  mutate(parentid = ifelse(is.na(parentid), median_parentid, parentid))

# Verify changes
sum(is.na(category_tree$parentid))

# Check the data type of each variable
str(category_tree)


# ------------------------------------------------
# Data Preprocessing for the event data 
# ------------------------------------------------

# Bind events to data frame
events <- rbindlist(events)

# Check for duplicates in events
sum(duplicated(events))

# Remove duplicates 
events <- unique(events)

# Verify
sum(duplicated(events))

# Check for NA's in events
colSums(is.na(events) | events == "")

# Replace the NA's in the transactions for View and Add to cart since both don't involve any transactions
events$transactionid <- replace_na(events$transactionid, 0)

# Check data type
str(events)

# Convert to appropiate data types
# events$visitorid <- as.character(events$visitorid)

# events$itemid <- as.character(events$itemid)

# Convert 'event' to factor
events[, event := as.factor(event)]

# Check datatype or class of the variable timestamp
class(events$timestamp)

# Convert to POSIXct# Calculate thresholds while removing NA values
events$timestamp <- as.POSIXct(events$timestamp / 1000, origin = "1970-01-01", tz = "UTC")


# --------------------------------------------------
# Exploratory Data Analysis
# --------------------------------------------------

# Data Visualisation
options(scipen = 999)

events_counts <- events %>% 
  group_by(event) %>% 
  summarise(count = n())

events_counts %>%
  ggplot(aes(x = event, y = count, fill = event)) + 
  geom_bar(stat = "identity", position = "dodge", color = NA, width = 0.7) +
  #geom_text(aes(label = count), vjust = -0.5, color = "black") +
  ylim (0, 3000000) +
  labs(
    title = "Distribution of User Events",
    x = "Event Type",
    y = "Count"
  )


# --------------------------------------------------
# Conversion Rates
# --------------------------------------------------

# Count the number of each event per visitor
user_event_counts <- dcast(events, visitorid ~ event, fun.aggregate = length, value.var = "event", fill = 0)
setnames(user_event_counts, old = c("view", "addtocart", "transaction"),
         new = c("num_view", "num_addtocart", "num_transaction"))


setDT(user_event_counts)
# Calculate conversion rates per visitor
user_event_counts[, conversion_view_to_add := ifelse(num_view > 0, num_addtocart / num_view, 0)]
user_event_counts[, conversion_add_to_transaction := ifelse(num_addtocart > 0, num_transaction / num_addtocart, 0)]
user_event_counts[, conversion_view_to_transaction := ifelse(num_view > 0, num_transaction / num_view, 0)]

# Inspect the calculated conversion rates
head(user_event_counts)

# Histogram for the view-to-add conversion rate
ggplot(user_event_counts, aes(x = conversion_view_to_add)) +
  geom_histogram(binwidth = 0.05, fill = "steelblue", color = "black", na.rm = TRUE) +
  labs(
    title = "Distribution of View-to-Add Conversion Rate",
    x = "Conversion Rate (Add-to-View)",
    y = "Number of Users"
  ) +
  theme_minimal()



# --------------------------------------------------
# Abnormalies / Bots Detection
# --------------------------------------------------

# setnames
# setnames(events, c("timestamp", "visitorid", "event", "itemid", "transaction"))

# Calculate event frequency per visitor (total events, events per minute, etc.)
# Assuming events are sorted by timestamp for each visitor
setorder(events, visitorid, timestamp)

# Calculate the time difference between consecutive events for each visitor
events[, time_diff := as.numeric(difftime(timestamp, shift(timestamp), units = "secs")), by = visitorid]

# Aggregate statistics per visitor: total events, median time difference, etc.
visitor_stats <- events[, .(
  total_events = .N,
  avg_time_diff = mean(time_diff, na.rm = TRUE),
  median_time_diff = median(time_diff, na.rm = TRUE)
), by = visitorid]

# Identify potential bots:
# For instance, flag users with unusually high total events or very low average time difference.
# These thresholds may need tuning based on your data.
# Calculate thresholds while removing NA values
bot_threshold_events <- quantile(visitor_stats$total_events, 0.95, na.rm = TRUE)   # Top 5% activity
bot_threshold_time <- quantile(visitor_stats$avg_time_diff, 0.05, na.rm = TRUE)      # Bottom 5% time gaps

visitor_stats[, bot_flag := (total_events > bot_threshold_events) | (avg_time_diff < bot_threshold_time)]

# Inspect flagged potential bots
potential_bots <- visitor_stats[bot_flag == TRUE]
print(potential_bots)

# Print number of potential bots
print(paste("Number of potential bots: ", nrow(potential_bots)))

# Show top ten bots
top_ten_bots <- potential_bots[order(-total_events)][1:10]
print(top_ten_bots)



# --------------------------------------------------
# Isolation Forest for Anomaly Detection
# --------------------------------------------------

# Prepare features for the Isolation Forest model.
# Use the aggregated metrics: total_events, avg_time_diff, and median_time_diff.
features <- as.data.frame(visitor_stats[, .(total_events, avg_time_diff, median_time_diff)])

# Check structure of features to ensure all columns are numeric
str(features)

# Initialize and fit the Isolation Forest model.
iso_model <- isolation.forest(features, ntrees = 100, sample_size = nrow(features), seed = 42)

# Get predictions which include an anomaly score for each user.
predictions <- predict(iso_model, newdata = features)

# Debugging: Check the structure and content of predictions.
str(predictions)
head(predictions)

# If predictions is an atomic vector of numeric values, add it directly.
visitor_stats[, anomaly_score := predictions]

# Define an anomaly threshold: Flag users whose anomaly score is in the top 1% as anomalies.
anomaly_threshold <- quantile(predictions, 0.99, na.rm = TRUE)
visitor_stats[, anomaly_flag := ifelse(anomaly_score > anomaly_threshold, -1, 1)]

# Check the updated visitor_stats
print(head(visitor_stats))

# -----------------------------
# STEP 6: Combine Detection Criteria
# -----------------------------
# Define thresholds for rule-based bot detection
bot_threshold_events <- quantile(visitor_stats$total_events, 0.95, na.rm = TRUE)
bot_threshold_time <- quantile(visitor_stats$avg_time_diff, 0.05, na.rm = TRUE)

# Create the bot_flag_rule column based on the thresholds
visitor_stats[, bot_flag_rule := (total_events > bot_threshold_events) | (avg_time_diff < bot_threshold_time)]


# Define a final flag for bots:
# A visitor is flagged as a bot if they meet either the rule-based criteria or the Isolation Forest criteria.
visitor_stats[, final_bot_flag := (bot_flag_rule == TRUE) | (anomaly_flag == -1)]

# Identify the final list of bot users.
bot_users <- visitor_stats[final_bot_flag == TRUE]
print(paste("Number of bots detected (combined):", nrow(bot_users)))

# -----------------------------
# STEP 7: Filter Out Bot Users from Events Data
# -----------------------------

# Remove all events associated with flagged bot users.
cleaned_events <- events[!visitorid %in% bot_users$visitorid]

# Optionally, check how many unique users remain.
print(paste("Remaining unique users after bot removal:", uniqueN(cleaned_events$visitorid)))


# -----------------------------------------------------------
# Scatter Plot of User Activity versus Time Difference
# -----------------------------------------------------------

# Assuming visitor_stats already contains total_events and avg_time_diff
ggplot(visitor_stats, aes(x = total_events, y = avg_time_diff)) +
  geom_point(alpha = 0.5, color = "purple") +
  scale_x_log10() +  # Log scale if there's a wide range in total_events
  labs(title = "Total Events vs. Average Time Difference per User",
       x = "Total Events (log scale)", y = "Average Time Difference (seconds)") +
  theme_minimal()



# ----------------------------------------------------
# Data Visualisation after Anomaly Detection
# ----------------------------------------------------
options(scipen = 999)

events_counts <- cleaned_events %>% 
  group_by(event) %>% 
  summarise(count = n())

events_counts %>%
  ggplot(aes(x = event, y = count, fill = event)) + 
  geom_bar(stat = "identity", position = "dodge", color = NA, width = 0.7) +
  #geom_text(aes(label = count), vjust = -0.5, color = "black") +
  ylim (0, 3000000) +
  labs(
    title = "Distribution of User Events After Bots Removal",
    x = "Event Type",
    y = "Count"
  )


# -----------------------------------------------
# Data Visualisation on Top Most Viewed Products
# -----------------------------------------------

# Filter the events data for view events only
view_events <- cleaned_events[event == "view"]

# Aggregate the number of views per product (itemid)
product_view_counts <- view_events[, .(view_count = .N), by = itemid]

# Order by view_count in descending order
setorder(product_view_counts, -view_count)

# Select the top 10 most viewed products
top_viewed_products <- head(product_view_counts, 10)

# Create a bar plot with ggplot2
ggplot(top_viewed_products, aes(x = reorder(itemid, view_count), y = view_count)) +
  geom_bar(stat = "identity", fill = "steelblue") +
  coord_flip() +
  labs(
    title = "Top 10 Most Viewed Products",
    x = "Product (itemid)",
    y = "View Count"
  ) +
  theme_minimal()


# --------------------------------------------------------
# Data Visualisation on Top Most Purchased Products
# --------------------------------------------------------

# Filter the events data for transaction events only
purchase_events <- cleaned_events[event == "transaction"]

# Aggregate the number of purchases per product (itemid)
product_purchase_counts <- purchase_events[, .(purchase_count = .N), by = itemid]

# Order by purchase_count in descending order
setorder(product_purchase_counts, -purchase_count)

# Select the top 10 most purchased products
top_purchased_products <- head(product_purchase_counts, 10)

# Create a bar plot with ggplot2
ggplot(top_purchased_products, aes(x = reorder(itemid, purchase_count), y = purchase_count)) +
  geom_bar(stat = "identity", fill = "forestgreen") +
  coord_flip() +  # Flip axes for better readability
  labs(
    title = "Top 10 Most Purchased Products",
    x = "Product (itemid)",
    y = "Purchase Count"
  ) +
  theme_minimal()


# ------------------------------------------
# Conversion funnel visualisation
# ------------------------------------------

# Aggregate counts for each event type using the cleaned events (if desired)
#funnel_data <- cleaned_events[, .(
#  num_view = sum(event == "view"),
#  num_addtocart = sum(event == "addtocart"),
#  num_transaction = sum(event == "transaction")
#)]

# Convert the data to long format for plotting
#funnel_long <- melt(funnel_data, measure.vars = c("num_view", "num_addtocart", "num_transaction"),
#                    variable.name = "stage", value.name = "count")

# ggplot(funnel_long, aes(x = stage, y = count)) +
#   geom_bar(stat = "identity", fill = "skyblue") +
#  labs(title = "Conversion Funnel", x = "Stage", y = "Event Count") +
#  theme_minimal()

# Aggregate counts for each event type from the cleaned events data
funnel_data <- cleaned_events %>%
  group_by(event) %>%
  summarise(count = n()) %>%
  mutate(event = factor(event, levels = c("view", "addtocart", "transaction")))

# Plot the conversion funnel
ggplot(funnel_data, aes(x = event, y = count)) +
  geom_bar(stat = "identity", fill = "steelblue") +
  labs(title = "Conversion Funnel", x = "Event Type", y = "Count") +
  theme_minimal()


# -----------------------------------------------------
# Data Visualisation on Time Series of Events Over Time
# ------------------------------------------------------

# Aggregate events by day (or week)
# daily_events <- cleaned_events[, .(total_events = .N), by = .(date = as.Date(timestamp))]

# ggplot(daily_events, aes(x = date, y = total_events)) +
#  geom_line(color = "blue") +
#  labs(title = "Daily Total Events", x = "Date", y = "Number of Events") +
#  theme_minimal()

# Aggregate events by day
monthly_events <- cleaned_events %>%
  mutate(date = as.Date(timestamp)) %>%
  group_by(date) %>%
  summarise(total_events = n())

# Plot the monthly events as a time series
ggplot(monthly_events, aes(x = date, y = total_events)) +
  geom_line(color = "blue") +
  labs(title = "Monthly Total Events", x = "Date", y = "Total Events") +
  theme_minimal()



# -----------------------------------------------------
# Data Visualisation on Relationship Between Overall Activity and Conversion Rates
# ------------------------------------------------------
visitor_stats <- cleaned_events %>%
  group_by(visitorid) %>%
  summarise(
    num_view = sum(event == "view"),
    num_addtocart = sum(event == "addtocart"),
    total_events = n(),
    avg_time_diff = mean(time_diff, na.rm = TRUE),
    median_time_diff = median(time_diff, na.rm = TRUE)
  ) %>%
  ungroup() %>%
  mutate(conversion_view_to_add = ifelse(num_view > 0, num_addtocart / num_view, NA))

# Check that the column exists
names(visitor_stats)
# Expected output now includes "conversion_view_to_add"

# Plot the relationship between total events and conversion rate
ggplot(visitor_stats, aes(x = total_events, y = conversion_view_to_add)) +
  geom_point(alpha = 0.5, color = "tomato") +
  scale_x_log10() +  # Log scale for total_events if needed
  labs(title = "Total Events vs Conversion (View to Add)", 
       x = "Total Events (log scale)", 
       y = "Conversion Rate (View to Add)") +
  theme_minimal()


# ---------------------------------------------------------
# Heatmap of Event Activity by Hour and Day of Week
# ----------------------------------------------------------

# Extract hour and day of week from datetime
cleaned_events[, hour := hour(timestamp)]
cleaned_events[, weekday := weekdays(timestamp)]

# Aggregate event counts by hour and weekday
heatmap_data <- cleaned_events[, .(count = .N), by = .(weekday, hour)]

# Reorder weekdays (optional, for proper ordering)
heatmap_data[, weekday := factor(weekday, levels = c("Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"))]

ggplot(heatmap_data, aes(x = hour, y = weekday, fill = count)) +
  geom_tile() +
  # geom_text(aes(label = count), color = "black", size = 3) +
  scale_fill_gradient(low = "white", high = "red") +
  labs(title = "Heatmap of Events by Hour and Weekday", x = "Hour of Day", y = "Weekday") +
  theme_minimal()



# ---------------------------------------------------------
# Data Preprocessing for item_properties
# ----------------------------------------------------------

# Bind item properties 1 & 2 in a data frame
item_properties <- do.call(rbind, c(item_properties_1, item_properties_2))

# Data Cleaning for item properties
# Check for duplicates in item_properties
# sum(duplicated(item_properties))

# Check for NA's in item properties
# colSums(is.na(item_properties) | item_properties == "")

# Convert to POSIXct
item_properties$timestamp <- as.POSIXct(item_properties$timestamp / 1000, origin = "1970-01-01", tz = "UTC")



# ---------------------------------------------------------
# Merging cleaned_events and item_properties
# ----------------------------------------------------------

# Merging datasets
# Perform a left Join
# A left join allows you to match each event with the most recent (previous) item property snapshot.

# Set event to data.table
setDT(cleaned_events)
setDT(item_properties)

# Order the data by itemid and timestamp
setorder(cleaned_events, itemid, timestamp)
setorder(item_properties, itemid, timestamp)

# leftjoin: for each event, get the most recent snapshot from item properties.
# This matches on 'itemid' and finds the snapshot with a timestamp less than or equal to the event timestamp.
events_items<- item_properties[cleaned_events, on = .(itemid, timestamp), roll = TRUE]


# ------------------------------------------------------------------------
# Replace the categoryid in the property column with it corresponding value
# -------------------------------------------------------------------------

# Update the 'property' column in events_items
# events_items[property == "categoryid", property := value]

# In the events_items data frame, update the 'property' column.
# For rows where 'property' equals "categoryid", replace it with the corresponding value from the 'value' column.
# Otherwise, keep the original 'property' value.
events_items <- events_items %>%
  mutate(property = if_else(property == "categoryid", 
                            value,     # Use the hashed value from 'value' column if property is "categoryid"
                            property)) # Otherwise, keep the original property

# Display the first few rows to verify the changes
# head(events_items)



# ------------------------------------------------------------------------
# Merge events_items and categoryid
# -------------------------------------------------------------------------

# Check the data types of the 'property' column in events_items and the 'categoryid' column in categorytree
str(events_items$property)
str(category_tree$categoryid)

# Convert both columns to character type to ensure they match
events_items <- events_items %>%
  mutate(property = as.character(property))

category_tree <- category_tree %>%
  mutate(categoryid = as.character(categoryid))

# Merge events_items with categorytree using a left join.
# This will attach the categorytree information to events_items where events_items$property matches categorytree$categoryid.
merged_df <- events_items %>%
  left_join(category_tree, by = c("property" = "categoryid"))

# Display the first few rows of the merged dataset to verify the result
# head(merged_df)

# Drop the columns "time_diff", "hour", and "weekday" from merged_df_all
merged_df <- merged_df %>% 
  select(-time_diff, -hour, -weekday)



# ------------------------------------------------------------------------
# Filtered availability and created a new column to have only availability
# -------------------------------------------------------------------------

# 1. Filter for available properties
merged_df_filtered <- merged_df %>%
  filter(property %in% c("available"))

# 2. Restructure or pivot the data so that each item has its categoryid & available as separate columns
merged_df_restructure <- merged_df_filtered %>%
  pivot_wider(names_from = property, values_from = value)

# 3. Convert availability to numeric and then to integer (0 or 1)
# First, convert to numeric and replace NAs with 0
merged_df_restructure <- merged_df_restructure %>%
  mutate(available = as.numeric(available)) 

# Replace NA's in 'available' with 0, then convert to integer
merged_df_restructure$available[is.na(merged_df_restructure$available)] <- 0
merged_df_restructure <- merged_df_restructure %>%
  mutate(available = as.integer(available))

# Ensure only the latest available status per itemid is kept
merged_df_restructure <- merged_df_restructure %>%
  group_by(itemid) %>%
  arrange(desc(timestamp)) %>%  # Keep the latest timestamp per item
  slice(1) %>%
  ungroup()

# Perform the left join safely
merged_df <- merged_df %>%
  left_join(merged_df_restructure %>% select(itemid, available), by = "itemid")


# -------------------------------------
# Renamed Columns
# -------------------------------------


# Rename column 'property' to 'categoryid'
final_df <- final_df %>% rename(categoryid = property)

# Remove rows where categoryid is "available"
final_df <- final_df %>% 
  filter(categoryid != "available")




# ----------------------------------------------------------
# Handling Missing Values
# ----------------------------------------------------------


# Convert final_df to a data.table
final_dt <- as.data.table(final_df)

# Replace missing values in 'available' with 0
final_dt[, available := ifelse(is.na(available), 0, available)]

# Replace missing values in 'parentid' with -1
final_dt[, parentid := ifelse(is.na(parentid), -1, parentid)]

# Verify that the replacements worked by printing the count of NA's in each column
print(colSums(is.na(final_dt)))



# ------------------------------------------------------------------------
# How does the availability of items impact user interactions?
# -------------------------------------------------------------------------
options(scipen = 999)

# Aggregate event counts by availability status, excluding NA values
availability_events <- final_df %>%
  filter(!is.na(available)) %>%  # Exclude NA values
  group_by(available, event) %>%
  summarise(count = n(), .groups = "drop")

# Plot the comparison
ggplot(availability_events, aes(x = event, y = count, fill = as.factor(available))) +
  geom_bar(stat = "identity", position = "dodge") +
  scale_fill_manual(values = c("0" = "red", "1" = "green"), labels = c("Unavailable", "Available")) +
  labs(title = "Impact of Item Availability on User Interactions",
       x = "Event Type", 
       y = "Number of Events", 
       fill = "Availability") +
  theme_minimal()




# ------------------------------------------------------------------------
# How do conversion rates vary across different times of the day?
# -------------------------------------------------------------------------
# Ensure timestamp is in proper datetime format
final_df <- final_df %>%
  mutate(hour = format(as.POSIXct(timestamp, origin = "1970-01-01", tz = "UTC"), "%H"))

# Aggregate conversion rates by hour
hourly_conversions <- final_df %>%
  group_by(hour) %>%
  summarise(conversion_view_to_add = sum(event == "addtocart") / sum(event == "view"),
            conversion_add_to_purchase = sum(event == "transaction") / sum(event == "addtocart"),
            .groups = "drop")

# Reshape for plotting
hourly_conversions_long <- pivot_longer(hourly_conversions, cols = c("conversion_view_to_add", "conversion_add_to_purchase"), names_to = "conversion_type", values_to = "rate")

# Plot conversion rates over time
ggplot(hourly_conversions_long, aes(x = as.numeric(hour), y = rate, colour = conversion_type)) +
  geom_line(size = 1) +
  scale_x_continuous(breaks = seq(0, 23, 1)) +
  labs(title = "Conversion Rates by Hour of the Day",
       x = "Hour of the Day",
       y = "Conversion Rate",
       colour = "Conversion Type") +
  theme_minimal()




# ------------------------------------------------------------------------
# What Is the Relationship Between User Session Duration and Purchase Likelihood?
# -------------------------------------------------------------------------
# Calculate session statistics per user
session_stats <- cleaned_events %>%
  group_by(visitorid) %>%
  summarise(
    session_duration = as.numeric(difftime(max(timestamp), min(timestamp), units = "mins")),
    total_transactions = sum(event == "transaction"),
    total_views = sum(event == "view"),
    conversion_rate = if_else(total_views > 0, total_transactions / total_views, NA_real_),
    .groups = "drop"
  ) %>%
  filter(!is.na(conversion_rate)) %>%  # remove users with NA conversion_rate
  filter(!is.na(session_duration))       # ensure session_duration is not NA

# Bin session durations using -Inf as the lower bound
session_stats <- session_stats %>%
  mutate(duration_bin = cut(session_duration, 
                            breaks = c(-Inf, 5, 10, 20, 30, Inf), 
                            labels = c("<5", "5-10", "10-20", "20-30", "30+"),
                            include.lowest = TRUE))

# Check the binning result (no NAs should appear)
table(session_stats$duration_bin, useNA = "ifany")

# Summarise average conversion rate for each duration bin
bin_summary <- session_stats %>%S
group_by(duration_bin) %>%
  summarise(
    avg_conversion_rate = mean(conversion_rate, na.rm = TRUE),
    count = n(),
    .groups = "drop"
  )

# Bar chart of average conversion rate by session duration bin
ggplot(bin_summary, aes(x = duration_bin, y = avg_conversion_rate, fill = duration_bin)) +
  geom_bar(stat = "identity") +
  labs(
    title = "Average Conversion Rate by Session Duration",
    x = "Session Duration (minutes) Bin",
    y = "Average Conversion Rate"
  ) +
  theme_minimal()




# ------------------------------------------------------------------------
# What is the distribution of event types across all users?
# -------------------------------------------------------------------------
# Aggregate total counts per event type from the final dataset
event_distribution <- final_df %>%
  group_by(event) %>%
  summarise(total = n(), .groups = "drop")

# Calculate overall sum of events
overall_total <- sum(event_distribution$total)

# Calculate the proportion of each event type
event_distribution <- event_distribution %>%
  mutate(proportion = total / overall_total)

# Plot the distribution as a bar chart with percentage labels
ggplot(event_distribution, aes(x = event, y = proportion, fill = event)) +
  geom_bar(stat = "identity", show.legend = FALSE) +
  scale_y_continuous(labels = percent_format(accuracy = 1)) +
  labs(title = "Distribution of Event Types Across Users",
       x = "Event Type",
       y = "Proportion of Events") +
  theme_minimal()





# ------------------------------------------------------------------------
# MODELLING
# -------------------------------------------------------------------------


# ------------------------------------------------------------------------
# Remove Na's in the final_df for memory optimisation
# -------------------------------------------------------------------------
# Check NA's in columns
colSums(is.na(final_df))

# Remove NA's in parentid and available
final_df_clean <- final_df[!is.na(final_df$parentid)]

final_df_clean <- final_df[!is.na(final_df$available)]

# Verify changes
colSums(is.na(final_df_clean))

# ------------------------------------------------------------------------
# Task 1
# When a customer comes to an e-commerce site, he looks for a product with particular 
# properties: price range, vendor, product type and etc. These properties are implicit, 
# so it's hard to determine them through clicks log. Try to create an algorithm which 
# predicts properties of items in "addtocart" event by using data from "view" events 
# for any visitor in the published log.
# -------------------------------------------------------------------------

library(randomForest)
library(dplyr)
library(tidyr)

# 1. Extract view events and add-to-cart events
views_df <- final_df_clean %>% filter(event == "view")
atc_df   <- final_df_clean %>% filter(event == "addtocart")

# 2. Aggregate view events per visitor and category (without converting categoryid)
view_features <- views_df %>%
  group_by(visitorid, categoryid) %>%
  summarise(views_count = n(), .groups = "drop") %>%
  pivot_wider(names_from = categoryid, 
              values_from = views_count, 
              values_fill = list(views_count = 0))

# Convert column names to syntactically valid names
colnames(view_features) <- make.names(colnames(view_features))

# 3. Merge the aggregated view features with add-to-cart events
training_data <- atc_df %>% left_join(view_features, by = "visitorid")

# 4. Prepare the training dataset:
#    Set the target variable as the categoryid of the add-to-cart event and convert it to a factor.
training_data <- training_data %>%
  mutate(target = as.factor(as.character(categoryid)))

# Select only the features from the aggregated view data and the target variable.
feature_data <- training_data %>%
  select(-timestamp, -itemid, -event, -transactionid, -parentid, -available, -categoryid)

# Check frequency of each target level in feature_data
target_counts <- table(feature_data$target)
print(target_counts)

# Define a threshold (e.g., only keep levels with more than 10 observations)
levels_to_keep <- names(target_counts)[target_counts > 10]

# Filter feature_data to keep only rows with target levels in levels_to_keep
feature_data <- feature_data[feature_data$target %in% levels_to_keep, ]

# Drop unused levels
feature_data$target <- droplevels(feature_data$target)


# Verify that there are no empty levels
print(table(feature_data$target))

# 5. Train a Random Forest classifier
set.seed(42)
rf_model <- randomForest(target ~ ., data = feature_data, na.action = na.omit)
print(rf_model)




# -----------------------------------------
# Confusion Matrix
# -----------------------------------------

library(caret)

# Predict on the training set 
predictions <- predict(rf_model, newdata = feature_data, na.action = na.omit)

# Create a confusion matrix comparing predictions and true target values
cm <- confusionMatrix(predictions, feature_data$target)
print(cm)
