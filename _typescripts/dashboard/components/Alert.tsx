import * as React from "react";

export interface IAlertProps { title: string; subtitle: string; }

export class Alert extends React.Component<IAlertProps, any> {
  constructor(props: IAlertProps) {
    super(props);
  }

  public render() {
    return <article className="message is-primary is-large">
      <div className="message-body">
        <strong>{this.props.title}</strong>
        {this.props.subtitle}
      </div>
    </article>;
  }
}
