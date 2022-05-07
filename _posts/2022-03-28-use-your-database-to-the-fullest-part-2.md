---
title: Use your database to the fullest (part 2)
thumb: blog-post-thumb-1.jpg
layout: article
---

[Last time](https://itguy.ro/2022/03/07/use-your-database-to-the-fullest.html) we used an aggregation pipeline to update the `time_to_respond` when an request was assigned to someone. 

We need to similarly compute the `time_to_resolve` which is the time from the issue was created until the time the issue was marked as resolved, minus the time while the issue was on hold. 

Each time we update the log, we need to update the `time_to_resolve` and add the time between the last entry and the current one, except if the last entry was On Hold. For simplicity, we won't show  the update of the `time_to_respond` in this aggregation, but that will need to be added to the aggregation pipeline also, and we won't show updating the log array since that was shown [previously](http://itguy.ro/2022/03/07/use-your-database-to-the-fullest.html)

```
db.requests.updateOne({"_id" : ObjectId("XXXX")},[{ 
    $set: {
        time_to_resolve:{
            $cond: {
                if: { $ne: ["$status","On Hold"]},
                then: {
                    $round: {
                        $divide: [{
                            $subtract: [
                                "$$NOW",
                                {$arrayElemAt:["$logs.date",-1]}
                            ]},
                            1000
                        ]}
                    },
                else: "$time_to_resolve"
                }
            }
        status: <new status>
        }
    }]
);
```


