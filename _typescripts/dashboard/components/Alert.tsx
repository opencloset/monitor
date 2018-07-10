import * as React from 'react';

export interface AlertProps { title: string, subtitle: string }

export class Alert extends React.Component<AlertProps, any> {
  constructor(props: AlertProps) {
    super(props);
  }

  render() {
    return <article className="message is-primary is-large">
      <div className="message-body">
        <strong>{this.props.title}</strong>
        {this.props.subtitle}
      </div>
    </article>;
  }
}
