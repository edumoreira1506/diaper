# Provides full CRUD for Partners. These are minimal representations of corresponding Partner records in PartnerBase.
# Though the functionality of Partners is actually fleshed out in PartnerBase, in DiaperBase, we maintain a collection
# of which Partners are associated with which Diaperbanks.
class PartnersController < ApplicationController
  include Importable

  def index
    @unfiltered_partners_for_statuses = Partner.where(organization: current_organization)
    @partners = Partner.where(organization: current_organization).class_filter(filter_params).alphabetized
  end

  def create
    @partner = current_organization.partners.new(partner_params)
    if @partner.save
      redirect_to partners_path, notice: "Partner added!"
    else
      flash[:error] = "Something didn't work quite right -- try again?"
      render action: :new
    end
  end

  def approve_application
    @partner = current_organization.partners.find(params[:id])
    response = DiaperPartnerClient.put(partner_id: @partner.id, status: "approved")
    if response.is_a?(Net::HTTPSuccess)
      @partner.approved!
      redirect_to partners_path, notice: "Partner approved!"
    else
      redirect_to partners_path, error: "Failed to update Partner data!"
    end
  end

  def show
    @partner = current_organization.partners.find(params[:id])
  end

  def new
    @partner = current_organization.partners.new
  end

  # NOTE(chaserx): this is confusing and could be renamed to reflect what it's returning/showing review_application
  def approve_partner
    @partner = current_organization.partners.find(params[:id])

    # TODO: create a service that abstracts all of this from PartnersController, like PartnerDetailRetriever.call(id: params[:id])

    # TODO: move this code to new service,
    @diaper_partner = DiaperPartnerClient.get(id: params[:id])
    @diaper_partner = JSON.parse(@diaper_partner, symbolize_names: true) if @diaper_partner
    @agency = if @diaper_partner
                @diaper_partner[:agency]
              else
                autovivifying_hash
              end
  end

  def edit
    @partner = current_organization.partners.find(params[:id])
  end

  def update
    @partner = current_organization.partners.find(params[:id])
    if @partner.update(partner_params)
      redirect_to partners_path, notice: "#{@partner.name} updated!"
    else
      flash[:error] = "Something didn't work quite right -- try again?"
      render action: :edit
    end
  end

  def destroy
    current_organization.partners.find(params[:id]).destroy
    redirect_to partners_path
  end

  def invite
    partner = current_organization.partners.find(params[:id])
    partner.register_on_partnerbase
    redirect_to partners_path, notice: "#{partner.name} invited!"
  end

  def recertify_partner
    @partner = current_organization.partners.find(params[:id])
    response = DiaperPartnerClient.put(partner_id: @partner.id, status: "recertification_required")
    if response.is_a?(Net::HTTPSuccess)
      @partner.recertification_required!
      redirect_to partners_path, notice: "#{@partner.name} recertification successfully requested!"
    else
      redirect_to partners_path, error: "#{@partner.name} failed to update partner records"
    end
  end

  private

  def autovivifying_hash
    Hash.new { |ht, k| ht[k] = autovivifying_hash }
  end

  def partner_params
    params.require(:partner).permit(:name, :email, :send_reminders)
  end

  def filter_params
    return {} unless params.key?(:filters)

    params.require(:filters).slice(:by_status)
  end
end


