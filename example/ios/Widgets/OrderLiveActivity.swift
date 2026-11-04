import ActivityKit
import AppIntents
import ExtensionBridgeKit
import SwiftUI
import WidgetKit

/// Draws the order Live Activity that Dart starts and updates.
struct OrderLiveActivity: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: OrderAttributes.self) { context in
      OrderLockScreenView(context: context)
        .activityBackgroundTint(Color.bridgeIndigo.opacity(0.85))
        .activitySystemActionForegroundColor(.white)
        .widgetURL(link)
    } dynamicIsland: { context in
      DynamicIsland {
        DynamicIslandExpandedRegion(.leading) {
          Text(context.attributes.emoji).font(.system(size: 40))
        }
        DynamicIslandExpandedRegion(.trailing) {
          EtaView(state: context.state).font(.title3.bold()).foregroundStyle(Color.bridgeBlue)
        }
        DynamicIslandExpandedRegion(.center) {
          VStack(spacing: 2) {
            Text(context.attributes.item).font(.headline)
            Text(OrderAttributes.steps[context.state.step].title)
              .font(.subheadline)
              .foregroundStyle(.secondary)
          }
        }
        DynamicIslandExpandedRegion(.bottom) {
          VStack(spacing: 10) {
            StepsView(step: context.state.step)
            HStack {
              Text(context.state.message).font(.caption).lineLimit(2)
              Spacer()
              AdvanceButton(context: context)
            }
          }
        }
      } compactLeading: {
        Text(context.attributes.emoji)
      } compactTrailing: {
        EtaView(state: context.state)
          .font(.caption.bold())
          .foregroundStyle(Color.bridgeBlue)
          .frame(maxWidth: 52)
      } minimal: {
        Text(context.attributes.emoji)
      }
      .widgetURL(link)
      .keylineTint(.bridgeBlue)
    }
  }

  private var link: URL? {
    ExtensionBridgeLinks.url("extensionbridge://order", source: "live_activity")
  }
}

private struct OrderLockScreenView: View {
  let context: ActivityViewContext<OrderAttributes>

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .top) {
        Text(context.attributes.emoji).font(.system(size: 36))
        VStack(alignment: .leading, spacing: 2) {
          Text(context.attributes.item).font(.headline)
          Text(context.state.message).font(.subheadline).foregroundStyle(.white.opacity(0.8))
            .lineLimit(2)
        }
        Spacer()
        VStack(alignment: .trailing, spacing: 2) {
          EtaView(state: context.state).font(.title2.bold())
          Text("ETA").font(.caption2).foregroundStyle(.white.opacity(0.7))
        }
      }
      HStack(spacing: 12) {
        StepsView(step: context.state.step)
        AdvanceButton(context: context)
      }
    }
    .foregroundStyle(.white)
    .padding(16)
  }
}

private struct EtaView: View {
  let state: OrderAttributes.ContentState

  var body: some View {
    if state.step >= OrderAttributes.lastStep {
      Image(systemName: "checkmark.circle.fill")
    } else if state.eta > .now {
      Text(timerInterval: Date.now...state.eta, countsDown: true)
        .monospacedDigit()
        .multilineTextAlignment(.trailing)
    } else {
      Text("Soon")
    }
  }
}

private struct StepsView: View {
  let step: Int

  var body: some View {
    HStack(spacing: 4) {
      ForEach(OrderAttributes.steps.indices, id: \.self) { index in
        Image(systemName: OrderAttributes.steps[index].symbol)
          .font(.caption.weight(.bold))
          .frame(width: 28, height: 28)
          .background(
            index <= step ? Color.bridgeBlue : Color.white.opacity(0.15), in: .circle)
        if index < OrderAttributes.lastStep {
          Capsule()
            .fill(index < step ? Color.bridgeBlue : Color.white.opacity(0.15))
            .frame(height: 4)
        }
      }
    }
    .foregroundStyle(.white)
  }
}

/// A Live Activity button: the intent runs Dart in the app process.
private struct AdvanceButton: View {
  let context: ActivityViewContext<OrderAttributes>

  var body: some View {
    if context.state.step < OrderAttributes.lastStep {
      Button(intent: AdvanceOrderIntent(activityID: context.activityID)) {
        Image(systemName: "forward.fill")
          .font(.subheadline.weight(.bold))
          .frame(width: 40, height: 32)
      }
      .buttonStyle(.plain)
      .foregroundStyle(.white)
      .background(Color.bridgePink, in: .capsule)
    }
  }
}
