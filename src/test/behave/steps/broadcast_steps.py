# Feature-specific step definitions for broadcast.feature.

from behave import when


@when('I enable live broadcasting without a configured connection')
def step_enable_broadcast_without_connection(context):
    raise NotImplementedError(
        "Pending the livestreaming enable control (the Broadcast settings "
        "page is a mock); scenario is a pinned @xfail placeholder")
