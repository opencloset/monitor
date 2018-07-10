import * as React from 'react';

export interface AlertProps { body: string }

export class Alert extends React.Component<AlertProps, any> {
  constructor(props: AlertProps) {
    super(props);
  }

  render() {
    return <article className="message is-primary is-large">
      <div className="message-body">{this.props.body}</div>
    </article>;
  }
}
