package com.projecttaskhub.task_service.config;

import org.springframework.amqp.core.*;
import org.springframework.amqp.rabbit.config.SimpleRabbitListenerContainerFactory;
import org.springframework.amqp.rabbit.connection.ConnectionFactory;
import org.springframework.amqp.rabbit.core.RabbitTemplate;
import org.springframework.amqp.support.converter.Jackson2JsonMessageConverter;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class RabbitConfig {

    // =============== EXCHANGES ===============
    @Bean
    public TopicExchange taskExchange() {
        return new TopicExchange("task.exchange");
    }

    @Bean
    public TopicExchange projectExchange() {
        return new TopicExchange("project.exchange");
    }

    // =============== QUEUES ===============
    @Bean
    public Queue taskEventQueue() {
        return QueueBuilder.durable("task.events.queue").build();
    }

    @Bean
    public Queue projectEventConsumerQueue() {
        return QueueBuilder.durable("project.events.consumer.queue").build();
    }

    // =============== BINDINGS ===============
    @Bean
    public Binding taskEventBinding() {
        return BindingBuilder
                .bind(taskEventQueue())
                .to(taskExchange())
                .with("task.events");
    }

    @Bean
    public Binding projectEventBinding() {
        return BindingBuilder
                .bind(projectEventConsumerQueue())
                .to(projectExchange())
                .with("project.events");
    }

    // =============== MESSAGE CONVERTER ===============
    @Bean
    public Jackson2JsonMessageConverter messageConverter() {
        return new Jackson2JsonMessageConverter();
    }

    // =============== RABBIT TEMPLATE ===============
    @Bean
    public RabbitTemplate rabbitTemplate(ConnectionFactory connectionFactory) {
        RabbitTemplate template = new RabbitTemplate(connectionFactory);
        template.setMessageConverter(messageConverter());
        return template;
    }

    // =============== LISTENER FACTORY ===============
    @Bean
    public SimpleRabbitListenerContainerFactory rabbitListenerContainerFactory(
            ConnectionFactory connectionFactory) {
        SimpleRabbitListenerContainerFactory factory = new SimpleRabbitListenerContainerFactory();
        factory.setConnectionFactory(connectionFactory);
        factory.setMessageConverter(messageConverter());
        return factory;
    }
}
