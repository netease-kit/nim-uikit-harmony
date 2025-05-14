/**
 * UIObserver
 * NIM-WS-TS
 *
 * @author hongru
 * @since 2025−04-18
 *
 * Copyright © 2025 Netease. All rights reserved.
 */

import UITraceLogger from './UITraceLogger';

const Domain = 'UITrace'

export class UIObserver {
  public static observer: UIObserver | undefined;

  public static getInstance(): UIObserver {
    if (!UIObserver.observer) {
      UIObserver.observer = new UIObserver();
    }
    return UIObserver.observer;
  }

  onWillClick(uiContext: UIContext) {
    uiContext.getUIObserver()?.on('willClick', (_event: ClickEvent, node?: FrameNode) => {
      const uniqueId = node?.getUniqueId();
      const ID = node?.getId();
      const pageInfo = uiContext.getPageInfoByUniqueId(uniqueId);
      const trackData = node?.getCustomProperty(ID);
      let eventParams: Record<string, string | number> = {
        'component_id': ID ?? '',
        'pageInfo': JSON.stringify(pageInfo ?? {}),
        'tackData': JSON.stringify(trackData ?? {})
      };
      UITraceLogger.write(Domain, 'willClick', eventParams)
    })
  }

  onScrollEvent(uiContext: UIContext) {
    uiContext.getUIObserver().on('scrollEvent', (info) => {
      UITraceLogger.write(Domain, 'scrollEvent', {
        'type': info.scrollEvent,
        'uniqueId': info.uniqueId,
        'offset': info.offset
      })
    })
  }

  onNavDestinationSwitch(uiContext: UIContext) {
    uiContext.getUIObserver().on('navDestinationSwitch', (info) => {
      UITraceLogger.write(Domain, 'navDestinationSwitch',
        {
          'operation': info.operation,
          'from': JSON.stringify(info.from),
          'to': JSON.stringify(info.to)
        })
    })
  }

  onRouterPageUpdate(uiContext: UIContext) {
    uiContext.getUIObserver().on('routerPageUpdate', (info) => {
      UITraceLogger.write(Domain, 'routerPageUpdate', {
        'name': info.name,
        'id': info.pageId,
        'index': info.index,
        'state': info.state
      })
    })
  }
}