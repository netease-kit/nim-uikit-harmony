import { V2NIMMessage } from "@nimsdk/base";

@ObservedV2
export class IsReceiveMsg {
  @Trace isReceiveMsg: boolean
  @Trace count: number
  @Trace messages: V2NIMMessage[] = []
  @Trace operation: IsReceiveMsgOperation = IsReceiveMsgOperation.ADD;

  constructor(isReceiveMsg: boolean, messages?: V2NIMMessage[], operation?: IsReceiveMsgOperation) {
    if (isReceiveMsg && messages && messages.length >= 1) {
      this.isReceiveMsg = isReceiveMsg;
      this.count = messages.length;
      this.messages = messages
    } else {
      this.isReceiveMsg = false;
      this.count = 0;
      this.messages = []
    }

    this.operation = operation ?? IsReceiveMsgOperation.ADD;
  }

  get yes(): boolean {
    return this.isReceiveMsg;
  }

  get no(): boolean {
    return !this.isReceiveMsg;
  }
}

export enum IsReceiveMsgOperation {
  ADD = 0,
  DELETE = 1
}
