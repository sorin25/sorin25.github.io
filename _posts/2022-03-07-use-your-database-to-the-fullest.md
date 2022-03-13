---
title: Use your database to the fullest
thumb: blog-post-thumb-1.jpg
layout: article
---

It pays to learn your database capabilities, especially for NoSQL ones. I recently took over a project that had overgrown it's original team. One of the requirements they had  was simple: track the time to respond and the time it took to resolve a request. They were using for back end a MongoDB database. 

One approach would be to fetch all the data from the database, and for each request you would go trough the attached logs and calculate both values, then sort and filter the data in client. Which would work fine for a small number of requests, or if the filter and sorting would not involve the values you would calculate. 

But imagine what happens when you have several thousands of requests and you have to find the top 10 that took the longest to resolve ?


A better way would be to compute the time to respond and the time to resolve in the database, before sending the data to the client, and send only 10 values instead of several thousands. Better yet, since this is a NoSQL environment we won't strive for normalization of the data, and we can pre-compute the values and store them in the document, so we don't have to repeat the same calculations over and over. 

## The data

Each change in status is stored in an array in the request document, let's name it `logs`. Each entry has a few elements `user`, `status`, `date` that are relevant in this case. 

The definition for **time to respond** is the time that passes from the moment the request is created until it's assigned to someone. Each requests starts with a log entry with `status` set to 'new'. The initial design had the assumption that the next log entry would always be the one for assigning the request to someone. At a first glance that would seem reasonable. We can use an [aggregation pipeline](https://docs.mongodb.com/v4.2/aggregation/) to compute additional fields. [$substract](https://docs.mongodb.com/v4.2/reference/operator/aggregation/subtract/index.html#subtract-two-dates) is used to get the difference in milliseconds the first 2 dates in the logs array, [$arrayElemAt](https://docs.mongodb.com/v4.2/reference/operator/aggregation/arrayElemAt/index.html) is used to access the first and second element of the log array. The formula `$logs.date` may seem strange, I can't find any documentation on it (except a [defect](https://jira.mongodb.org/browse/SERVER-37246) and an associated documentation [task](https://jira.mongodb.org/browse/DOCS-12068)), but it works.

```
db.requests.aggregate([{
    $addFields: {
        time_to_respond: {
            $round : {
                $divide: [
                    {
                        $subtract: [
                            {$arrayElemAt: ["$logs.date",1]},
                            {$arrayElemAt: ["$logs.date",0]}
                        ]
                    },
                    1000
                ]
            }
        }
    }
}])
```

What happens when you introduce some other types of entries in the log, and the second entry won't always be the assignment one. To handle that you need to filter the log array and get the first match:

```
db.requests.aggregate([{
    $addFields: {
        time_to_respond: {
            $let: {
                vars: {
                    al: {
                        $arrayElemAt: [
                            {
                                $filter : {
                                    input: "$logs",
                                    cond: { "$eq" : [ "$$this.status", "In Progress"]}
                                },
                            },
                            0]
                    },
                },
                in: {
                    $round : {
                        $divide: [
                            {
                                $subtract: [
                                    "$$al.date",
                                    {$arrayElemAt: ["$logs.date",0]}
                                ]
                            },
                            1000
                        ]
                    }
                }
            }
        }
    }
}])
```
[$let](https://docs.mongodb.com/v4.2/reference/operator/aggregation/let/index.html) is used to create a "variable", [$filter](https://docs.mongodb.com/v4.2/reference/operator/aggregation/filter/) is used to get only the "In Progress" log entries. An alternative approach would be to use [$indexOfArray](https://docs.mongodb.com/v4.2/reference/operator/aggregation/indexOfArray/), however, in that case special care is required to handle the case where there are no "In Progress" entries. 

As you can see the computations will become more and more complex, and we haven't even started on the time to resolve. What if we update the `time_to_respond` key when we assign someone to the request. This is a bit more complicated and requires a fairly new MongoDB server, in order to be able to use an update instruction with an aggregation pipeline so you can refer to the updated document. 

## Use an aggregation pipeline during the update to update the `time_to_respose`

In order to be able to refer to the existing document in an update, you need to use an aggregation pipeline. When updating the request as assigned to someone, we would like to:
 - set the request assignee and status, 
 - add a log entry with the assignment info 
 - update the `time_to_response`

The first two can be done with a simple update:

```
db.requests.updateOne({_id: ObjectId('xxx')},{
    $set: {assingee: "XXX", "status": "In Progress"},
    $push: { logs: {...}}})
```

However updating the `time_to_response` requires referencing the previous version of the document and computing the difference between the first log entry and the current log entry. To complicate the things more, there is no support for `$push` in the update aggregation pipeline. 

```
db.requests.updateOne({"_id" : ObjectId("XXXX")},[{ 
    $set: {
        time_to_respond:{
            $cond: {
                if: { $eq: ["$status","New"]},
                then: {
                    $round: {
                        $divide: [{
                            $subtract: [
                                "$$NOW",
                                {$arrayElemAt:["$logs.date",0]}
                            ]},
                            1000
                        ]}
                    },
                else: "$time_to_respond"
                }
            }
        }
    },{
    $set: {
        logs: {
            $concatArrays: [
                "$logs", 
                [{
                    "status" : "In Progress",
                    "user" : "sorin",
                    "date" : "$$NOW", 
                    "description" : "Issue assigned to OPS Team"
                }]]
            }
        }
    }]
);

```

Part 2 will cover computing time to resolve field.

