---
layout: post
title: Connecting to an Lightning Node via gRPC
block-height: 845910
categories: ["lightning", "technology", "bitcoin"]
---

### Overview

Have you ever wanted to connect to your [LND lightning node](https://github.com/lightningnetwork/lnd) from another application? What about [CLN](https://github.com/ElementsProject/lightning)? Well there are a couple of ways I've used. One is to use this [typescript library](https://github.com/alexbosworth/lightning). The other option which I will cover is via gRPC methods. Technically the library by Alex Bosworth is a wrapper overtop the gRPC methods and you should probably have a high level understanding of what's going on under the hood as there are some things when dealing with gRPC that you should be aware of.

### Using Lightning Typescript

As you can see in the [example here](https://github.com/alexbosworth/lightning) it's very straightforward to connect to the node. Note that there is also the `ln-service` library he has written but that lacks typings.

```typescript
const { authenticatedLndGrpc } = require("lightning");

const { lnd } = authenticatedLndGrpc({
  cert: "base64 encoded tls.cert file",
  macaroon: "base64 encoded admin.macaroon file",
  socket: "127.0.0.1:10009",
});
```

This is very straightforward and if you want to call some different methods you can now use your above created `lnd` object. This is great!

```typescript
const nodePublicKey = (await lnService.getWalletInfo({ lnd })).public_key;
```

Subscriptions are a prime use case for gRPC methods and require a long standing connection. If the connection is broken you'll need to figure out how to re-create the subscription.

```typescript
const { once } = require("events");
const { subscribeToInvoice } = require("ln-service");
const id = "invoiceIdHexString";
const sub = subscribeToInvoice({ id, lnd });
const [invoice] = await once(sub, "invoice_updated");
```

Here you can see we are subscribing to a particular invoice and as such the method is waiting for an updated invoice event to occur once. If you are manually working with something like this, you'll need to handle that and cancel the subscription.

This is a pretty good primer on that library and hopefully gives you some help in making a decision. What if you aren't

### Going Raw Dog

Let's use .NET 8 as an example. I've written a simple application in it using this technique for acting as a proxy for lightning payments. This however is a bit more complicated to setup.

In your project file you'll need to add a few nuget packages. Notice the `Google.protobuf`, `Grpc.Net.Client` and `Grpc.Tool` packages. These are what we need to create our `gRPC` client and then the
group containing the relative paths to `.proto` files. These files contain the definitions or interface for the exposed `gRPC` methods of our node. Please feel free to look at the official [documentation](https://grpc.io/docs/what-is-grpc/introduction/) for an overvie of gRPC and protocol buffers. That's a bit outside the scope here.

```xml
<Project Sdk="Microsoft.NET.Sdk.Web">

  <PropertyGroup>
    <TargetFramework>net8.0</TargetFramework>
    <Nullable>enable</Nullable>
    <ImplicitUsings>enable</ImplicitUsings>
  </PropertyGroup>

  <ItemGroup>
    <PackageReference Include="Microsoft.AspNetCore.OpenApi" Version="7.0.9" />
    <PackageReference Include="Swashbuckle.AspNetCore" Version="6.5.0" />
    <PackageReference Include="Google.Protobuf" Version="3.24.2" />
    <PackageReference Include="Grpc.Net.Client" Version="2.56.0" />
    <PackageReference Include="Grpc.Tools" Version="2.57.0">
      <IncludeAssets>runtime; build; native; contentfiles; analyzers; buildtransitive</IncludeAssets>
      <PrivateAssets>all</PrivateAssets>
    </PackageReference>
  </ItemGroup>
  <ItemGroup>
    <Protobuf Include="Grpc\lightning.proto" GrpcServices="Client" />
    <Protobuf Include="Grpc\invoices.proto" GrpcServices="Client" protoRoot="Grpc"/>
    <Protobuf Include="Grpc\router.proto" GrpcServices="Client" protoRoot="Grpc"/>
  </ItemGroup>
</Project>

```

The first thing we'll need to do is create the grpc channel. I am using the file path here to the SSL cert of the node and the macaroon, but you could also use hex or base64 if you would prefer. This is just an example.

```c#
 public LnGrpcClientService(IConfiguration configuration)
    {
        pathToMacaroon = configuration["AppSettings:PathToMacaroon"]!;
        pathToSslCertificate = configuration["AppSettings:PathToSslCertificate"]!;
        GRPCHost = configuration["AppSettings:GRPCHost"]!;
    }

    private GrpcChannel GetGrpcChannel()
    {
        var rawCert = File.ReadAllBytes(pathToSslCertificate);
        Environment.SetEnvironmentVariable("GRPC_SSL_CIPHER_SUITES", "HIGH+ECDSA");
        var x509Cert = new X509Certificate2(rawCert);

        var httpClientHandler = new HttpClientHandler
        {   // HttpClientHandler will validate certificate chain trust by default. This won't work for a self-signed cert.
            // Therefore validate the certificate directly
            ServerCertificateCustomValidationCallback = (httpRequestMessage, cert, cetChain, policyErrors)
                => x509Cert.Equals(cert)
        };

        var credentials = ChannelCredentials.Create(new SslCredentials(), CallCredentials.FromInterceptor(AddMacaroon));

        var channel = GrpcChannel.ForAddress(
            $"https://{GRPCHost}",
            new GrpcChannelOptions
            {
                HttpHandler = httpClientHandler,
                Credentials = credentials
            });

        return channel;
    }

    private Task AddMacaroon(AuthInterceptorContext context, Metadata metadata)
    {
        metadata.Add(new Metadata.Entry("macaroon", GetMacaroon()));
        return Task.CompletedTask;
    }

    private string GetMacaroon()
    {
        byte[] macaroonBytes = File.ReadAllBytes(pathToMacaroon);
        var macaroon = BitConverter.ToString(macaroonBytes).Replace("-", "");
        return macaroon;
    }
```

Following that we have a valid channel that can be used in our application. In my application, I created two seperate clients to interact with my node, but you can create one like this

```c#
    public Invoices.InvoicesClient GetInvoiceClient()
    {
        var channel = GetGrpcChannel();
        var client = new Invoices.InvoicesClient(channel);
        return client;
    }
```

The `Invoices.InvoicesClient(channel)` is coming from the definition defined in our proto files. If you look at the `invoices.proto`

```proto
syntax = "proto3";

import "lightning.proto";

package invoicesrpc;

option go_package = "github.com/lightningnetwork/lnd/lnrpc/invoicesrpc";
```

you can see the definition as defined and as a result the .NET package for the gRPC client autogenerates our classes to interface with those `gRPC` methods.
I hope this helps someone. Note that most languages have available various grpc libraries to similar things. For a view of the repo that this code came from you can check it out [here](https://github.com/nodlAndHodl/lnproxy).
