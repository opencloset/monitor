import * as React from 'react';

export interface AlertProps { header: string; body: string; }

export class Alert extends React.Component<AlertProps, any> {
  constructor(props: AlertProps) {
    super(props);
  }

  render() {
    return <article className="message is-large">
      <div className="message-header">
        <p>{this.props.header}</p>
      </div>
      <div className="message-body">
        {this.props.body}
      </div>
    </article>;
  }
}
