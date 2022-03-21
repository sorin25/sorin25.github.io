---
title: Use the source Luke!
thumb: blog-post-thumb-2.jpg
layout: article
---

It's not in the documentation ?!? Then look into the sources, and you will find it!

I recently had to upgrade [pika](https://pika.readthedocs.io/en/stable/) and ended up introducing a breaking issue. I'm using a Rabbit MQ that is hosted on IBM Cloud and has a self signed certificate, and the very old pika version that I was using was ignoring that, but not the new one, which complained about it.

It took some experimentation, but I was able to guess that [ssl_options](https://pika.readthedocs.io/en/stable/modules/parameters.html?highlight=URLParameters#pika.connection.URLParameters.ssl_options) can be used to set the pika.SSLOptions also, despite the documentation not being very clear. So I ended up with a simple code that would configure pika to use the appropriate certificate. 

```
parameters = pika.URLParameters(os.environ['MESSAGE_QUEUE'])
context = ssl.SSLContext()
context.load_verify_locations(os.environ['IBM_DATABASE_CA'])
parameters.ssl_options = pika.SSLOptions(context)
connection = pika.BlockingConnection(parameters)
```

While this works, I realized that I was using also a Mongo Database that was using the same certificate, but PyMongo was using `ssl.CERT_NONE` to avoid the same issue.
Instead of repeating the same approach, I wondered, what about the default directory/certificate location, can't I just add the certificate there and have it pick up automatically ?

Looking at the [ssl](https://docs.python.org/3/library/ssl.html) documentation, there is no clear answer as to where is the default location. But there is [ssl.get_default_verify_paths()](https://docs.python.org/3/library/ssl.html#ssl.get_default_verify_paths). It doesn't have a direct answer, but it points us to the right direction.

Let's look into the [source code](https://github.com/python/cpython/blob/5c3201e146b251017cd77202015f47912ddcb980/Lib/ssl.py#L441) - the function is a wrapper to [_ssl.get_default_verify_paths()](https://github.com/python/cpython/blob/e91b0a7139d4a4cbd2351ccb5cd021a100cf42d2/Modules/_ssl.c#L5204).

Double click -> Right Click -> Search Google for "`X509_get_default_cert_file_env`", and the first result points to [x509_def.c](https://docs.huihoo.com/doxygen/openssl/1.0.1c/x509__def_8c.html) where we can find our function [X509_get_default_cert_file_env](https://docs.huihoo.com/doxygen/openssl/1.0.1c/x509__def_8c.html#a73455f8271ee6b251eb99bfac8246e31).

And in a few steps, we get to line 95 from [cryptlib.h](https://docs.huihoo.com/doxygen/openssl/1.0.1c/cryptlib_8h_source.html) where we can find the that name of environment variable we are looking for may be `SSL_CERT_FILE`.  

Set that to point to the IBM Databases Certificate file, remove the `ssl.CERT_NONE` from the PyMongo initialization code, and it works!

Open source guys are busy, they don't always have time to document every detail, but they give you the sources, and you can figure it out yourself!
