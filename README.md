# Recommendation System Analysis and Modelling

## Introduction
Recommendation systems are essential for delivering personalised user experiences across various platforms, including e-commerce, streaming services, social media and news websites.
These systems leverage historical and user-specific data to generate recommendations, enhancing user satisfaction, engagement and conversion rates. From e-commerce platforms and streaming services to social media and news websites, recommendation systems are vital in shaping the user experience.

The ability to provide personalised recommendations has significant business value. By understanding user preferences, behaviours and interactions, organisations can boost user retention, increase sales and improve customer satisfaction. As recommendation systems continue to evolve, they face the challenge of offering accurate, diverse and relevant suggestions while handling large volumes of data and maintaining real-time performance. 

This project aims to develop a recommendation system that leverages historical user data to provide tailored recommendations across different domains, such as product recommendations, content suggestions and service optimisation.

## CRISP DM Framework
The analysis followed the CRISP-DM methodology, which includes the following stages:

Business Understanding

a. Define the project objectives and business goals.

b. Identify key questions that need to be answered. 

Data Understanding 

a. Collect data from various sources.

b. Explore the data (e.g., summary statistics, missing values, patterns).

c. Identify potential issues like inconsistencies, duplicates and outliers

Data Preparation

a. Clean and preprocess the data.

b. Handle missing values and inconsistencies.

c. Transform data into the right format for analysis.

d. Feature selection and engineering.

Modelling

a. Apply statistical or machine learning models.

b. Train models using relevant algorithms.

c. Tune hyperparameters to improve performance.

Evaluation

a. Assess the model’s performance using metrics.

b. Compare models and select the best one.

c. Ensure the model meets business objectives.

Deployment

a. Implement the model in a real-world environment.

b. Monitor its performance and make improvements if needed.

### 1. Business Understanding

The objectives were defined below, followed by the formulation of analytic questions to guide the modelling process.

Key objectives of the project include:

a. Develop Personalised Recommendations: Tailor suggestions based on user behaviour and past interactions.

b. Address Diverse Use Cases: Implement systems for product, content and service recommendations.

c. Utilise Historical Data: Leverage past user actions to make accurate predictions.

d. Enhance User Engagement: Improve user satisfaction and retention through relevant suggestions.

e. Ensure Scalability & Real-Time Performance: Handle large data volumes and provide recommendations promptly.

f. Boost Business Metrics: Increase sales and conversion rates through better user personalisation.

g. Balance Accuracy & Diversity: Provide relevant but varied recommendations to avoid monotony.

Analytic Questions:


### 2. Data Understanding:

The dataset consists of three files: events.csv, item_properties.csv and category_tree.csv, which collectively describe the interactions and properties of items on an e-commerce website. The data, collected over months, is raw and contains hashed values due to confidentiality concerns. The goal of publishing this dataset is to support research in recommender systems using implicit feedback.

2.1 Behaviour Data (events.csv)

The behaviour data includes a total of 2,756,101 events, with 2,664,312 views, 69,332 add-to-cart actions and 22,457 transactions, recorded from 1,407,580 unique visitors. Each event corresponds to one of three types of interactions: "view", "addtocart", or "transaction". These implicit feedback signals are crucial for recommender systems:

View: Represents a user showing interest in an item.

Add to Cart: Indicates a higher level of intent to purchase.

Transaction: Represents a completed purchase.

2.2 Item Properties (item_properties.csv)

This file contains 20,275,902 rows, representing various properties of 417,053 unique items. Each property may change over time (e.g., price updates), with each row capturing a snapshot of an item’s property at a specific timestamp. For items with constant properties, only a single snapshot is recorded. The file is split into two due to its size, and it contains detailed item information, which is essential for building item profiles and understanding how item properties influence user behaviour.

2.3 Category Tree (category_tree.csv)

The category_tree.csv file outlines the hierarchical structure of item categories. It provides a category-based organisation of the products, which can help in grouping items into broader categories or subcategories. This file is important for building models that recommend items within specific categories or using category-based clustering for recommendations.

### 3. Data Preparation: 
#### a. Data Processing of Event file
• To ensure the dataset was ready for analysis, a meticulous data preparation process was carried out as follows:

• The events file was read using a read-in-chunk function. This function enables large files to be loaded in smaller manageable portions, thereby preventing memory overload and ensuring efficiency. The chunks were then bound into a single data frame.

• The dataset was inspected thoroughly to understand its structure and content. Columns were verified to match the document description and then standardised to "timestamp", "visitorid", "event", "itemid" and "transaction" to ensure consistency throughout the project.

• Raw timestamps provided in Unix format (milliseconds since the epoch) were converted into a human-readable date-time format (POSIXct) using the lubridate package. This conversion was essential for any subsequent time-based analysis.

• Duplicate rows were removed to eliminate any repeated events that might skew the analysis.

• The dataset was sorted chronologically by visitorid and timestamp. This ordering was crucial for computing time differences between consecutive events for each visitor. The shift function in data.table was used to calculate these differences in seconds. Naturally, the first event for each visitor resulted in an NA value since no preceding event existed. Negative time differences or other anomalies were checked to ensure data integrity.


##### b. Bot Detection and Removal

• A rule-based approach was employed to identify potential bots by flagging visitors with total event counts in the top 5% or average time differences in the bottom 5%.

• An Isolation Forest model was applied on aggregated features such as total events, average and median time differences. This anomaly detection technique highlighted users whose behaviour patterns deviated significantly from typical user activity.

• Both detection methods were combined and events associated with flagged bot users were removed to ensure that only genuine user behaviour remained in the final dataset.

• After ensuring that the dataset was free of duplicates, missing values and bot-generated noise, the cleaned data was exported as a new CSV file, serving as a reliable foundation for further analysis.

• Once cleaned and standardised, the dataset was exported as a new CSV file.

#### c. Data Processing of Timestamp and Merging Item Properties

• Binding Item Properties Files:
The two parts of the item properties file (part 1 and part 2) were combined into a single data frame. A read-in-chunk approach was applied earlier to manage large files. The code uses the do.call function along with rbind to concatenate the two lists of item property data into one unified dataset.

• Timestamp Conversion:
Timestamps in the item properties dataset were originally in Unix time (milliseconds since the epoch). These were converted to a human-readable POSIXct format using the as.POSIXct function. The division by 1000 adjusts the value from milliseconds to seconds. Specifying the time zone as "UTC" ensures consistency across all timestamp values.

• Preparing Item Properties for Merging:
The item properties dataset, which contains multiple snapshots per item reflecting changes over time, was first sorted by itemid and timestamp to organise the snapshots chronologically. All snapshots were preserved to retain the temporal evolution of item properties rather than reducing the data to one row per item.

#### d. Merging cleaned events dataset and item properties dataset
• Preparing the Events Data for Merging:
The cleaned events dataset was converted into a data.table and sorted by itemid and timestamp. This step aligns the events data with the ordering of the item properties and is essential for performing a left join with a rolling mechanism.

• Merging the Datasets Using a left Join:
A left join was performed with the events file as the primary table. The join was executed on the itemid and timestamp columns with the roll = TRUE parameter. This approach ensures that every event is enriched with the most recent snapshot from the item properties that occurred before or at the time of the event, preserving all events while accurately reflecting the temporal context of each item property snapshot.

#### e. Data Processing of Category Tree: 
The category tree dataset was carefully cleaned to ensure its integrity before merging with other datasets.

• Handling Missing Values in parentid: The parentid column contained 25 missing values. Since parentid represents hierarchical relationships between categories, imputing missing values was necessary. The median value of the parentid column was computed and used to replace the missing values. This approach helps maintain the categorical structure while minimising bias.

### Final Merge 
To enrich the events_items dataset with category information, a left join was performed with the categorytree dataset. This ensures that all event records are retained while relevant category details are appended.

• Ensuring Data Type Consistency:
The property column in events_items and the categoryid column in categorytree were converted to character type to prevent mismatches.

• Merging the Datasets: 
A left join was executed, matching the property column from events_items with the categoryid column from categorytree. This operation retains all records in events_items and adds category details where available.
