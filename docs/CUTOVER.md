# Moving your domain to Cloud Run: the checklist

For the owner of the domain, step by step. The old setup keeps running until
the last step, so going back is always a DNS change away.

This checklist has never been run against a live project or a live domain.
The commands are the documented ones from Google Cloud and common DNS
practice. `chatbot.example.com` stands for your domain.

## 1. Before the switch day

- [ ] Production is deployed and the smoke test passes on its own address:
      `SMOKE_URL=https://<service>.run.app scripts/smoke.sh`
- [ ] Choose the front door for your domain. Google's options, from their
      [custom domain page](https://cloud.google.com/run/docs/mapping-custom-domains):
  - **Global external Application Load Balancer** (Google's recommendation).
    Billed separately, and not created by this repository; it is a separate
    change, reviewed and priced first.
  - **Firebase Hosting** in front of the service.
  - **Cloud Run domain mapping**. Simplest, but Google lists it as Preview
    and "not production-ready" because of latency. Fine for staging.
- [ ] Write down the current DNS record for `chatbot.example.com` (type,
      value, TTL). This is your way back.
- [ ] Lower that record's TTL to 300 seconds, and wait at least the old TTL
      before the switch, so the change spreads quickly and so does a rollback.
- [ ] Get the HTTPS certificate ready before traffic moves. With the load
      balancer, a Google-managed certificate through Certificate Manager with
      DNS authorization can be issued before the domain points at it.
- [ ] Test the new front door before DNS changes, by sending the domain name
      to its address directly:
      `curl --resolve chatbot.example.com:443:<new IP> https://chatbot.example.com/health`
- [ ] If the old app held an AI provider key, create a new key for the new
      setup and store it only in Secret Manager (see the main README).
- [ ] Agree on a quiet time for the switch and who watches it.

## 2. The switch

- [ ] Change the DNS record to the new front door (A/AAAA records for the load
      balancer IP, or the records Google gives you for Firebase Hosting or
      domain mapping).
- [ ] Check from outside your network that the name resolves to the new
      value: `dig +short chatbot.example.com`
- [ ] Run the smoke test against the domain:
      `SMOKE_URL=https://chatbot.example.com scripts/smoke.sh`
- [ ] Open the page in a browser, ask a question, click a citation, and
      check the PDF opens on the cited page.

## 3. If something is wrong

- [ ] Put the DNS record back to the value you wrote down. With the short TTL,
      most visitors are back on the old setup within minutes.
- [ ] Nothing on the old setup was changed, so there is nothing else to undo.

## 4. After a quiet period you agree on

- [ ] Raise the TTL back to its usual value.
- [ ] Turn off the old setup, and delete the keys and secrets it used.
- [ ] Remove any access you granted for the move (for example a temporary
      role for the person doing it).
