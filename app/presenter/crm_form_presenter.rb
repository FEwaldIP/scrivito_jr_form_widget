class CrmFormPresenter < CrmFormAttributes

  def attribute_names
    @type.standard_attrs.keys + @type.custom_attrs.keys
  end

  def initialize(widget, request, controller)
    @widget = widget
    @activity = widget.activity
    @page = widget.obj
    @params = request.params["crm_form_presenter"]

    if request.post? && widget.id == @params[:widget_id]
      @params.delete("widget_id")
      redirect_after_submit(controller, widget, self.submit)
    end
  end

  def submit
    contact = nil

    if @params['custom_email'] && @params['custom_last_name']
      contact = manipulate_or_create_user
    end

    if contact
      set_params_for_activty(contact)
      add_contact_to_event(contact) if @widget.event_id.present?
    end

    @params["title"] = @params[:title].empty? ? @activity.id : @params[:title]
    @params["type_id"] = @activity.id
    @params["state"] = @activity.attributes['states'].first

    activity = Crm::Activity.create(@params)

    return {status: "success", message: "Your form was send successfully"}
  rescue Crm::Errors::InvalidValues => e
    return {status: "error", message: e.validation_errors}
  end

  private
  def manipulate_or_create_user
    contact = Crm::Contact.where(:email, :equals, @params['custom_email']).and(:last_name, :equals, @params['custom_last_name']).first
    unless contact
      contact = Crm::Contact.create({
        first_name: @params['custom_first_name'],
        last_name: @params['custom_last_name'],
        email: @params['custom_email'],
        language: 'de'
      })
    end

    add_tags_to(contact)

    return contact
  end

  def add_contact_to_event(contact)
    Crm::EventContact.create({
      contact_id: contact.id,
      event_id: @widget.event_id,
      state: 'registered'
    })
  end

  def add_tags_to(contact)
    if @widget.tags
      tags = contact.tags + @widget.tags.split("|")
      contact.update({tags: tags})
    end
  end

  def set_params_for_activty(contact)
    if @params["title"] == ""
      @params["title"] = @activity.id
    end

    @params["contact_ids"] = contact.id
  end

  def redirect_path(page, widget)
    obj = redirect_obj(page, widget)
    obj.binary? ? obj.try(:binary_url) : "/#{obj.id}"
  end

  def redirect_obj(page, widget)
    (widget.respond_to?('redirect_to') && widget.redirect_to.present?) ? widget.redirect_to : page
  end

  def redirect_after_submit(controller, widget, submit_message)
    if submit_message[:status] == "success"
      controller.redirect_to(redirect_path(@page, widget), notice: submit_message[:message])
    elsif submit_message[:status] == "error"
      controller.redirect_to("/#{@page.id}", alert: submit_message[:message])
    end
  end
end
