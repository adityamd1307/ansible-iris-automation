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

> Topic 2 diagrams:
> - [sharding-architecture.md](sharding-architecture.md) — data nodes, node 1, optional compute
> - [combined-future-architecture.md](combined-future-architecture.md) — conceptual Topic 1 + Topic 2
>
> Export PNGs with the Mermaid CLI (see commands in each file).
