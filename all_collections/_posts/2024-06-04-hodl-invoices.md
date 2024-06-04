---
layout: post
title: What are Hodl Invoices?
block-height: 846498
categories: ["lightning", "technology", "bitcoin"]
---

### LND Hodl Invoice

At the moment the only implementation of lightning nodes that supports this feature is LND. You can see here from this [PR](https://github.com/lightningnetwork/lnd/pull/2022) that a Hodl invoice, is one that will wait until the receiver chooses to settle it (within in the expiry of the HTLC). In the PR there are mentioned 4 use cases (there are many more), but I think example 4 is something most can understand.

### Atomic Pizza Swap

```
Example 4: pizza delivery service wanting to offer "no pizza no pay".

A customer generates a random preimage and adds the hash of it to the pizza order.

The delivery service creates a hold invoice tied to this hash and returns the invoice to the customer.

Customer pays the invoice.

At this point, the delivery service can accept the payment, but not settle it because it doesn't know the preimage yet.

Then the driver goes out to deliver the pizza.

At the door he asks the customer for the preimage,
verifies that it is indeed the preimage of the hold invoice for this order and hands over the pizza.

Verification can even be done offline.

The delivery service can then settle the invoice when the driver returns with the preimage.

Atomic pizza swap completed.

```

As you can see these offer some pretty powerful use cases even though this one is simplistic, it enables something like an escrow service.

### LnProxy

Another use case that I've implemented them is in an LnProxy service. Basically you create a request to the proxy, that will wrap an invoice like below. The service will attempt to pay out the requested invoice once it sees the hodl invoice has been paid, and can relinquish funds once it has the preimage from the final destination invoice. Pretty neat trick. I've mentioned that repo before, but here you can see the [repo for more comprehensive code](https://github.com/nodlAndHodl/lnproxy) and some checks. For a valuation of the proxy spec look [here](https://github.com/lnproxy/spec).

```c#
var hodlInvoice = new AddHoldInvoiceRequest()
{
    Memo = !string.IsNullOrWhiteSpace(payReqDescription) ?
        payReqDescription : payReqFromInvoice.Description,
    DescriptionHash = !string.IsNullOrWhiteSpace(payReqHash) ?
        HexStringHelper.HexStringToByteString(payReqHash) :
        HexStringHelper.HexStringToByteString(payReqFromInvoice.DescriptionHash),
    Hash = HexStringHelper.HexStringToByteString(payReqFromInvoice.PaymentHash),
    ValueMsat = valueMsat,
    CltvExpiry = (uint)cltvExpiry,
    Expiry = CalculateExpiry(payReqFromInvoice)
};

var invoiceResponse = _lnGrpcService.GetInvoiceClient().AddHoldInvoice(hodlInvoice);
```


I hope you found this helpful. Until next time. 