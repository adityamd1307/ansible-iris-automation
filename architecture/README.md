# architecture/

Architecture diagrams for the POC (deliverable 5.1 #1).

- `ansible-iris-architecture.md` - Topic 1: controller, primary, backup,
  arbiter, web gateways, HAProxy VIP, access flow, and the mirror gap
  that the automation closes. Diagrams are in Mermaid (text) so they are
  diff-able and reviewable.

## Exporting to PNG (for the handover/slide pack)

The suggested final package expects `.png` files here. Generate them from
the Mermaid source with the Mermaid CLI:

```bash
npx @mermaid-js/mermaid-cli -i ansible-iris-architecture.md -o ansible-iris-architecture.png
```

or paste the code block into https://mermaid.live and export.

> Topic 2 (`sharding-architecture.png`) and the combined future
> architecture are Week-3/Week-4 deliverables and are intentionally not
> included in this Week-2 Topic-1 package.
