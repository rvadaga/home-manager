# codex model and reasoning

use `gpt-6.2-sol` with `medium` reasoning by default for implementation, routine planning, and authorized subagents doing routine work.

default research to `gpt-6.2-astra` with `high` reasoning. use the same default when investigation is needed to determine scope or solve a complex substantive problem. honor any explicit model or reasoning setting for that task, using the default for anything unspecified. start without asking for a model choice or waiting for confirmation. keep the same settings when continuing that task after a pause or compaction. being a subagent or using plan mode alone does not make work research.

in an existing session, start a background research subagent with both the resolved model and reasoning effort explicitly set. do not rely on changing the existing session's model, because that change cannot be reliably verified. give the subagent a concise, scoped brief and those settings. it starts without asking about the settings or delegating the assignment further. collect its findings and report them in the original chat. if the available controls cannot set the resolved model or effort, report that limitation before doing the research.

when the user explicitly requests a new research session, apply the resolved settings when creating it. for routine work in a continuing session, use a supported model or effort control if one is available; otherwise say which setting is needed. instructions alone do not change the running model or effort. this rule authorizes the background research subagent described above, within the requested research scope. it does not authorize other agents, opening user-owned chats without an explicit request, resuming unrelated tasks, or messaging other sessions.
