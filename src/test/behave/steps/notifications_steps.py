# Placeholder step definitions for the @sub/notifications scenarios in
# sound.feature, browse.feature and broadcast.feature.
#
# Contract when implementing:
#   - Content assertions ("the notification ... should be visible/sticky",
#     "no notification ...", "details ... mention ...") read the read-only
#     getNotifications RPC command (JSON list of {text, details, flags};
#     mirrors the getLibraryState two-step pattern in src/qml/rpcserve.cpp).
#   - Drawer/bell steps address the notification drawer and bell via
#     _wait_for_visible/_wait_for_hidden on mainWindow/notificationDrawer
#     (requires the objectName prerequisites in MainWindow.qml and
#     NotificationDrawer.qml).
#   - "I trigger a library scan from the header menu" opens the header logo
#     context menu (mainWindow/globalContextMenu, Menu-overlay workaround
#     convention) and walks "Library" > "Scan"; the logo uses a TapHandler,
#     so it follows the _activate_library_search retry-with-verification
#     exception documented in AGENTS.md.
#
#    Text drafted autonomously by an AI agent (for a human reviewer to
#    check, amend, and implement).
#    -- drafted autonomously by an AI agent --

from behave import when, then


@when('the notification "{text}" is visible')
def step_notification_visible_now(context, text):
    raise NotImplementedError(
        "Needs getNotifications RPC + wait machinery (getLibraryState pattern)")


@when('I trigger a library scan from the header menu')
def step_trigger_library_scan_from_header_menu(context):
    raise NotImplementedError(
        "Needs header logo menu navigation (TapHandler + globalContextMenu)")


@when('I attempt to load a missing track on deck {deck:d}')
def step_attempt_load_missing_track(context, deck):
    raise NotImplementedError(
        "Needs loadTrack RPC with a nonexistent path (test/missing-ui-interaction)")


@when('I click the "{label}" action of the "{title}" notification')
def step_click_notification_action(context, label, title):
    raise NotImplementedError(
        "Needs notification CTA button names in NotificationDrawer.qml "
        "(delegates + action buttons addressed via spix, e.g. "
        "notificationDrawer/<notificationItem>/notificationAction_<label>), "
        "resolving the notification by title")


@then('the notification "{text}" should be visible')
def step_notification_visible(context, text):
    raise NotImplementedError("Needs getNotifications RPC")


@then('the notification "{text}" should not be visible')
def step_notification_hidden(context, text):
    raise NotImplementedError("Needs getNotifications RPC")


@then('the notification "{text}" should be sticky')
def step_notification_sticky(context, text):
    raise NotImplementedError("Needs getNotifications RPC + flags")


@then('no notification should be visible')
def step_no_notifications(context):
    raise NotImplementedError("Needs getNotifications RPC")


@then('the notification drawer should not be visible')
def step_drawer_hidden(context):
    raise NotImplementedError(
        "Needs mainWindow/notificationDrawer objectName (NotificationDrawer.qml)")


@then('the notification bell should be enabled')
def step_bell_enabled(context):
    raise NotImplementedError(
        "Needs notificationBellButton objectName + fixed enabled binding "
        "(MainWindow.qml)")


@then('the notification details should mention the failure reason')
def step_details_mention_failure_reason(context):
    raise NotImplementedError("Needs getNotifications RPC")


@then('the notification details should mention "{text}"')
def step_details_mention(context, text):
    raise NotImplementedError("Needs getNotifications RPC")
