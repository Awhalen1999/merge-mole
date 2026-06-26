# Urgent — menu-bar mole test

Test fixture for the **urgent** priority variant of the new menu-bar icon.

When a review-requested PR is triaged as `urgent`, the mole glyph should tint
**red** in the menu bar (amber for `high`, plain template otherwise — driven by
`AppModel.badgePriority`).

This PR exists only to exercise that path. It is intentionally framed as **urgent**
so AI triage rates it `urgent` and the mole turns red. Safe to close once verified.
