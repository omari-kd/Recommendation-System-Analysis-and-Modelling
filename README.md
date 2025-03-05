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
#### a. Event file
• To ensure the dataset was ready for analysis, a meticulous data preparation process was carried out as follows:

• The events file was read using a read-in-chunk function. This function enables large files to be loaded in smaller manageable portions, thereby preventing memory overload and ensuring efficiency. The chunks were then bound into a single data frame.

• The dataset was inspected thoroughly to understand its structure and content. Columns were verified to match the document description and then standardised to "timestamp", "visitorid", "event", "itemid" and "transaction" to ensure consistency throughout the project.

• Raw timestamps provided in Unix format (milliseconds since the epoch) were converted into a human-readable date-time format (POSIXct) using the lubridate package. This conversion was essential for any subsequent time-based analysis.

• Duplicate rows were removed to eliminate any repeated events that might skew the analysis.

• The dataset was sorted chronologically by visitorid and timestamp. This ordering was crucial for computing time differences between consecutive events for each visitor. The shift function in data.table was used to calculate these differences in seconds. Naturally, the first event for each visitor resulted in an NA value since no preceding event existed. Negative time differences or other anomalies were checked to ensure data integrity.


##### Bot Detection and Removal

• A rule-based approach was employed to identify potential bots by flagging visitors with total event counts in the top 5% or average time differences in the bottom 5%.

• An Isolation Forest model was applied on aggregated features such as total events, average and median time differences. This anomaly detection technique highlighted users whose behaviour patterns deviated significantly from typical user activity.

• Both detection methods were combined and events associated with flagged bot users were removed to ensure that only genuine user behaviour remained in the final dataset.

• After ensuring that the dataset was free of duplicates, missing values and bot-generated noise, the cleaned data was exported as a new CSV file, serving as a reliable foundation for further analysis.

• Once cleaned and standardised, the dataset was exported as a new CSV file.
